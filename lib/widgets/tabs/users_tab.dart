import 'package:flutter/material.dart';
import 'package:painel_windowns/services/auth_service.dart';

class UsersTab extends StatefulWidget {
  final AuthService authService;

  const UsersTab({
    super.key,
    required this.authService,
  });

  @override
  State<UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<UsersTab> {
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.authService.isAdmin) {
      _loadUsers();
    }
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await widget.authService.getUsers();

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success']) {
          _users = List<Map<String, dynamic>>.from(result['users']);
        } else {
          _errorMessage = result['message'];
        }
      });
    }
  }
  
  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  void _showUserDialog({Map<String, dynamic>? user}) {
    final isEditing = user != null;
    final usernameController = TextEditingController(text: user?['username'] ?? '');
    final emailController = TextEditingController(text: user?['email'] ?? '');
    final passwordController = TextEditingController();
    // O campo 'sector' agora é usado para os prefixos
    final sectorController = TextEditingController(text: user?['sector'] ?? '');
    String selectedRole = user?['role'] ?? 'user';
    bool isLoadingDialog = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'Editar Utilizador' : 'Criar Utilizador'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: usernameController,
                    decoration: const InputDecoration(labelText: 'Nome de Utilizador', prefixIcon: Icon(Icons.person), border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email), border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  if (!isEditing)
                    TextFormField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Senha', prefixIcon: Icon(Icons.lock), border: OutlineInputBorder()),
                    ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedRole,
                    decoration: const InputDecoration(labelText: 'Papel', prefixIcon: Icon(Icons.security), border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'user', child: Text('Utilizador')),
                      DropdownMenuItem(value: 'admin', child: Text('Administrador')),
                    ],
                    onChanged: (value) {
                      setDialogState(() => selectedRole = value!);
                    },
                  ),
                  const SizedBox(height: 16),
                  if (selectedRole == 'user')
                    TextFormField(
                      controller: sectorController,
                      decoration: const InputDecoration(
                        labelText: 'Prefixos de Dispositivos Visíveis',
                        prefixIcon: Icon(Icons.visibility),
                        border: OutlineInputBorder(),
                        hintText: 'Separados por vírgula (ex: Enfermagem, UTI)',
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoadingDialog ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: isLoadingDialog ? null : () async {
                if (usernameController.text.trim().isEmpty ||
                    emailController.text.trim().isEmpty ||
                    (!isEditing && passwordController.text.isEmpty) ||
                    (selectedRole == 'user' && sectorController.text.trim().isEmpty)) {
                  _showSnackbar('Preencha todos os campos obrigatórios', isError: true);
                  return;
                }

                setDialogState(() => isLoadingDialog = true);

                final userData = {
                  'username': usernameController.text.trim(),
                  'email': emailController.text.trim(),
                  'role': selectedRole,
                  'sector': selectedRole == 'user' ? sectorController.text.trim() : 'Global',
                  if (!isEditing) 'password': passwordController.text,
                };

                Map<String, dynamic> result;
                if (isEditing) {
                  result = await widget.authService.updateUser(user['_id'], userData);
                } else {
                  result = await widget.authService.createUser(userData);
                }

                if (mounted) {
                  setDialogState(() => isLoadingDialog = false);
                  if (result['success']) {
                    Navigator.of(context).pop();
                    _showSnackbar(isEditing ? 'Utilizador atualizado com sucesso' : 'Utilizador criado com sucesso');
                    _loadUsers();
                  } else {
                    _showSnackbar(result['message'], isError: true);
                  }
                }
              },
              child: isLoadingDialog
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(isEditing ? 'Atualizar' : 'Criar'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteUserDialog(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text('Tem certeza que deseja excluir o utilizador "${user['username']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final result = await widget.authService.deleteUser(user['_id']);
              if (mounted) {
                if (result['success']) {
                  _showSnackbar('Utilizador excluído com sucesso');
                  _loadUsers();
                } else {
                  _showSnackbar(result['message'], isError: true);
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[600], foregroundColor: Colors.white),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.authService.isAdmin) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.security, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('Acesso Restrito', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey[700])),
            const SizedBox(height: 8),
            Text('Apenas administradores podem gerenciar utilizadores.', style: TextStyle(fontSize: 16, color: Colors.grey[600]), textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Gerenciamento de Utilizadores', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800])),
              Row(
                children: [
                  IconButton(onPressed: _loadUsers, icon: const Icon(Icons.refresh), tooltip: 'Atualizar'),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(onPressed: _showUserDialog, icon: const Icon(Icons.add), label: const Text('Novo Utilizador')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: Colors.red[50], border: Border.all(color: Colors.red[300]!), borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  Icon(Icons.error, color: Colors.red[600], size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_errorMessage!, style: TextStyle(color: Colors.red[700]))),
                ],
              ),
            ),

          if (_isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(32.0), child: CircularProgressIndicator()))
          else
            Expanded(
              child: SingleChildScrollView(
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Utilizador')),
                    DataColumn(label: Text('Email')),
                    DataColumn(label: Text('Papel')),
                    DataColumn(label: Text('Visibilidade (Prefixos)')),
                    DataColumn(label: Text('Criado em')),
                    DataColumn(label: Text('Ações')),
                  ],
                  rows: _users.map((user) {
                    final createdAt = DateTime.tryParse(user['created_at'] ?? '') ?? DateTime.now();
                    final formattedDate = '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year}';
                    
                    return DataRow(
                      cells: [
                        DataCell(Row(children: [
                          CircleAvatar(radius: 16, backgroundColor: user['role'] == 'admin' ? Colors.red[600] : Colors.blue[600],
                            child: Text(user['username'][0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
                          const SizedBox(width: 8),
                          Text(user['username']),
                        ])),
                        DataCell(Text(user['email'])),
                        DataCell(Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: user['role'] == 'admin' ? Colors.red[100] : Colors.blue[100], borderRadius: BorderRadius.circular(12)),
                          child: Text(user['role'] == 'admin' ? 'Admin' : 'Utilizador',
                            style: TextStyle(color: user['role'] == 'admin' ? Colors.red[700] : Colors.blue[700], fontSize: 12, fontWeight: FontWeight.w600)),
                        )),
                        DataCell(Text(user['sector'] ?? 'N/A')),
                        DataCell(Text(formattedDate)),
                        DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(onPressed: () => _showUserDialog(user: user), icon: Icon(Icons.edit, color: Colors.blue[600]), tooltip: 'Editar'),
                          IconButton(onPressed: () => _showDeleteUserDialog(user), icon: Icon(Icons.delete, color: Colors.red[600]), tooltip: 'Excluir'),
                        ])),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
