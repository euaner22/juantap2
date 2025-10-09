import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:juantap/pages/admin/email_service_responder.dart';

class ManageUsersPage extends StatefulWidget {
  const ManageUsersPage({super.key});

  @override
  State<ManageUsersPage> createState() => _ManageUsersPageState();
}

class _ManageUsersPageState extends State<ManageUsersPage> {
  final _queryCtrl = TextEditingController();
  String _roleFilter = 'All';
  late final DatabaseReference _usersRef;
  List<_UserRow> _rows = [];
  bool _loading = true;

  String _generatePassword(int length) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789@#%&!';
    final rand = Random.secure();
    return List.generate(length, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  @override
  void initState() {
    super.initState();
    _usersRef = FirebaseDatabase.instance.ref('users');
    _loadUsers();
  }

  void _loadUsers() {
    _usersRef.onValue.listen((e) {
      final List<_UserRow> rows = [];
      for (final user in e.snapshot.children) {
        rows.add(_UserRow(
          uid: user.key ?? '',
          name: (user.child('username').value ?? '') as String,
          email: (user.child('email').value ?? '') as String,
          role: (user.child('role').value ?? 'user') as String,
          status: (user.child('status').value ?? 'Active') as String,
        ));
      }

      rows.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      setState(() {
        _rows = rows;
        _loading = false;
      });
    });
  }

  List<_UserRow> get _filtered {
    final query = _queryCtrl.text.trim().toLowerCase();
    return _rows.where((r) {
      final matchesRole =
          _roleFilter == 'All' || r.role.toLowerCase() == _roleFilter.toLowerCase();
      final matchesQuery = query.isEmpty ||
          r.name.toLowerCase().contains(query) ||
          r.email.toLowerCase().contains(query);
      return matchesRole && matchesQuery;
    }).toList();
  }

  Future<void> _updateStatus(_UserRow row, String newStatus) async {
    await _usersRef.child(row.uid).update({'status': newStatus});
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${row.role} ${row.name} set to $newStatus')));
    }
  }

  Future<void> _deleteUser(_UserRow row) async {
    await _usersRef.child(row.uid).remove();
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${row.role} ${row.name} deleted')));
    }
  }

  Future<void> _showAddResponderDialog() async {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    const role = "responder";
    const status = "Active";

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFAFCFF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Create Responder Account",
          style: TextStyle(
            color: Color(0xFF084C41),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: "Responder Name",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(
                labelText: "Responder Email",
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E88E5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Create"),
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final email = emailCtrl.text.trim();

              if (name.isEmpty || email.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please fill in all fields")),
                );
                return;
              }

              final emailPattern = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
              if (!emailPattern.hasMatch(email)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Invalid email format")),
                );
                return;
              }

              try {
                final password = _generatePassword(10);
                final auth = FirebaseAuth.instance;

                final methods = await auth.fetchSignInMethodsForEmail(email);
                if (methods.isNotEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Email already registered")),
                  );
                  return;
                }

                final userCred = await auth.createUserWithEmailAndPassword(
                  email: email,
                  password: password,
                );
                await userCred.user?.sendEmailVerification();

                await _usersRef.child(userCred.user!.uid).set({
                  "username": name,
                  "email": email,
                  "role": role,
                  "status": status,
                  "phone": "",
                });

                final success = await EmailResponderService.sendResponderAccountEmail(
                  email: email,
                  username: name,
                  password: password,
                  role: role,
                );

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? "Responder '$name' created ✅ Email sent!"
                          : "Responder created, but email failed ❌",
                    ),
                  ),
                );

                if (mounted) Navigator.pop(ctx);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Error: $e")),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFC8F4E4),
            Color(0xFFA7E2C9),
            Color(0xFF7FD1AE),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🌿 Header + Add button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Manage Accounts",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF084C41),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E88E5), Color(0xFF38EF7D)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text(
                      "Add Responder",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    onPressed: _showAddResponderDialog,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 🌿 Search + Filter
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4FFF9),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _queryCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Search by name or email',
                        prefixIcon: Icon(Icons.search, color: Color(0xFF084C41)),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 14),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4FFF9),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: DropdownButton<String>(
                    value: _roleFilter,
                    icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF084C41)),
                    dropdownColor: const Color(0xFFFAFCFF),
                    underline: const SizedBox(),
                    style: const TextStyle(color: Color(0xFF084C41)),
                    items: const [
                      DropdownMenuItem(value: 'All', child: Text('All Roles')),
                      DropdownMenuItem(value: 'user', child: Text('User')),
                      DropdownMenuItem(value: 'responder', child: Text('Responder')),
                      DropdownMenuItem(value: 'admin', child: Text('Admin')),
                    ],
                    onChanged: (v) => setState(() => _roleFilter = v ?? 'All'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 🌿 Accounts Table
            Expanded(
              child: Card(
                color: const Color(0xFFFAFCFF),
                elevation: 6,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _UsersDataTable(
                    rows: _filtered,
                    onSuspend: (r) => _updateStatus(r, 'Suspended'),
                    onActivate: (r) => _updateStatus(r, 'Active'),
                    onDelete: _deleteUser,
                    onResetPassword: (r) async {
                      try {
                        await FirebaseAuth.instance.sendPasswordResetEmail(email: r.email);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Password reset email sent to ${r.email} ✅')),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------- Data Table --------------------
class _UsersDataTable extends StatelessWidget {
  final List<_UserRow> rows;
  final void Function(_UserRow) onSuspend;
  final void Function(_UserRow) onActivate;
  final void Function(_UserRow) onDelete;
  final void Function(_UserRow) onResetPassword;

  const _UsersDataTable({
    required this.rows,
    required this.onSuspend,
    required this.onActivate,
    required this.onDelete,
    required this.onResetPassword,
  });

  @override
  Widget build(BuildContext context) {
    final totalUsers = rows.length;
    final responders = rows.where((r) => r.role == 'responder').length;
    final admins = rows.where((r) => r.role == 'admin').length;
    final suspended = rows.where((r) => r.status == 'Suspended').length;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal, // ✅ allows horizontal scrolling
      child: SizedBox(
        width: 1200, // ✅ wider layout for table
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4EFFB),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildSummaryItem("Users", totalUsers, const Color(0xFF1E88E5)),
                    _buildSummaryItem("Responders", responders, const Color(0xFF38EF7D)),
                    _buildSummaryItem("Admins", admins, const Color(0xFF8E24AA)),
                    _buildSummaryItem("Suspended", suspended, Colors.redAccent),
                  ],
                ),
              ),
              const SizedBox(height: 4),

              PaginatedDataTable(
                header: null,
                rowsPerPage: 6,
                columnSpacing: 80, // ✅ expanded horizontal space
                horizontalMargin: 24,
                headingRowHeight: 70,
                dataRowMinHeight: 70,
                dataRowMaxHeight: 80,
                headingRowColor:
                WidgetStateProperty.all(const Color(0xFFD7F9E9)),

                columns: const [
                  DataColumn(
                    label: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 38, vertical: 10),
                      child: Text(
                        'Name',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 38, vertical: 10),
                      child: Text(
                        'Email',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 38, vertical: 10),
                      child: Text(
                        'Role',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 38, vertical: 10),
                      child: Text(
                        'Status',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 38, vertical: 10),
                      child: Text(
                        'Actions',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                ],

                source: _UsersSource(rows, onSuspend, onActivate, onDelete, onResetPassword),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, int value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, color: color, size: 10),
        const SizedBox(width: 6),
        Text(
          "$label: ",
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF084C41),
          ),
        ),
        Text(
          value.toString(),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _UsersSource extends DataTableSource {
  final List<_UserRow> rows;
  final void Function(_UserRow) onSuspend;
  final void Function(_UserRow) onActivate;
  final void Function(_UserRow) onDelete;
  final void Function(_UserRow) onResetPassword;

  _UsersSource(this.rows, this.onSuspend, this.onActivate, this.onDelete, this.onResetPassword);

  @override
  DataRow? getRow(int index) {
    if (index >= rows.length) return null;
    final r = rows[index];
    return DataRow(cells: [
      DataCell(Padding(padding: const EdgeInsets.symmetric(horizontal: 38), child: Text(r.name.isEmpty ? '(Unnamed)' : r.name))),
      DataCell(Padding(padding: const EdgeInsets.symmetric(horizontal: 38), child: Text(r.email))),
      DataCell(Padding(padding: const EdgeInsets.symmetric(horizontal: 38), child: Text(r.role))),
      DataCell(Padding(
        padding: const EdgeInsets.symmetric(horizontal: 38),
        child: Text(
          r.status,
          style: TextStyle(
            color: r.status == 'Active' ? Colors.green : Colors.redAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
      )),
      DataCell(Row(
        children: [
          IconButton(
            icon: const Icon(Icons.key, color: Color(0xFF1E88E5)),
            tooltip: 'Reset Password',
            onPressed: () => onResetPassword(r),
          ),
          IconButton(
            icon: Icon(
              r.status == 'Active'
                  ? Icons.pause_circle_outline
                  : Icons.play_circle_outline,
              color: r.status == 'Active' ? Colors.orange : Colors.green,
            ),
            tooltip: r.status == 'Active' ? 'Suspend' : 'Activate',
            onPressed: () =>
            r.status == 'Active' ? onSuspend(r) : onActivate(r),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            tooltip: 'Delete User',
            onPressed: () => onDelete(r),
          ),
        ],
      )),
    ]);
  }

  @override
  bool get isRowCountApproximate => false;
  @override
  int get rowCount => rows.length;
  @override
  int get selectedRowCount => 0;
}

// -------------------- Data Model --------------------
class _UserRow {
  final String uid;
  final String name;
  final String email;
  final String role;
  final String status;

  _UserRow({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.status,
  });
}
