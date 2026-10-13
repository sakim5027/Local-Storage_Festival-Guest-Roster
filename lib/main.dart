// In-Class Activity 09 — Build Local Storage part 2
// Student: Seul An Kim
// Date: October 13, 2026

import 'package:flutter/material.dart';

import 'database_helper.dart';

//Initialize database helper before running the app
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final helper = DatabaseHelper();

  try {
    await helper.init();
  } catch (error, stackTrace) {
    debugPrint('Database initialization failed: $error\n$stackTrace');
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'Could not open local storage. Restart the app and check the logs.',
            ),
          ),
        ),
      ),
    );
    return;
  }
  runApp(DirectoryApp(helper: helper));
}

//Directory App
class DirectoryApp extends StatelessWidget {
  final DatabaseHelper helper;
  const DirectoryApp({super.key, required this.helper});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fall Festival Roster',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.brown, useMaterial3: true),
      home: FolderListScreen(helper: helper),
    );
  }
}

//Fall Festival Roster Screen
class FallFestivalRoster extends StatefulWidget {
  final DatabaseHelper helper;
  const FallFestivalRoster({super.key, required this.helper});

  @override
  State<FallFestivalRoster> createState() => _FallFestivalRosterState();
}

class _FallFestivalRosterState extends State<FallFestivalRoster> {
  //text controllers
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final ageController = TextEditingController();

  //guest records
  List<Map<String, dynamic>> guests = [];

  int recordCount = 0;
  int? editingId;

  bool isLoading = true;
  bool isBusy = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    refreshGuests();
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  //return true if the refresh succeeds
  Future<bool> loadGuests() async {
    try {
      final rows = await widget.helper.queryAllRows();

      if (!mounted) return false;

      final count = await widget.helper.queryRowCount();

      if (!mounted) return false;

      setState(() {
        guests = rows;
        recordCount = count;
        errorMessage = null;
      });

      return true;
    } catch (error, stackTrace) {
      debugPrint('Read failed: $error\n$stackTrace');

      if (!mounted) return false;

      setState(() {
        errorMessage = 'Could not load festival guests: $error';
      });

      return false;
    }
  }

  //refresh guest list
  Future<void> refreshGuests() async {
    if (isBusy) return;

    setState(() {
      isLoading = true;
      isBusy = true;
    });
    try {
      await loadGuests();
    } finally {
      if (mounted) {
        setState(() {
          isBusy = false;
          isLoading = false;
        });
      }
    }
  }

  //form validation methods
  String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter a guest name.';
    }
    return null;
  }

  String? validateAge(String? value) {
    final age = int.tryParse(value?.trim() ?? '');

    if (age == null) {
      return 'Please enter a whole number.';
    }

    if (age < 0 || age > 130) {
      return 'Age must be between 0 and 130.';
    }

    return null;
  }

  //add or save guest
  Future<void> saveGuest() async {
    if (isBusy) return;

    if (!formKey.currentState!.validate()) {
      return;
    }

    final name = nameController.text.trim();
    final age = int.tryParse(ageController.text.trim())!;
    final selectedId = editingId;

    setState(() {
      isBusy = true;
    });
    try {
      String successMessage;

      if (selectedId == null) {
        // INSERT: omit ID so SQLite assigns it
        final id = await widget.helper.insert({
          DatabaseHelper.columnName: name,
          DatabaseHelper.columnAge: age,
        });

        successMessage = 'Guest added successfully. ID: $id';
      } else {
        // UPDATE: use selected guest ID
        final updated = await widget.helper.update({
          DatabaseHelper.columnId: selectedId,
          DatabaseHelper.columnName: name,
          DatabaseHelper.columnAge: age,
        });

        if (updated == 0) {
          if (!mounted) return;
          showMessage(
            'Guest ID $selectedId no longer exists. Reloading roster.',
          );
          await loadGuests();
          return;
        }

        successMessage =
            'Guest ID $selectedId updated. Rows affected: $updated';
      }

      if (!mounted) return;

      // Clear form only after successful write
      clearForm();

      // Refresh separately after successful write
      final refreshed = await loadGuests();

      if (!mounted) return;

      if (refreshed) {
        showMessage(successMessage);
      } else {
        showMessage('$successMessage. Saved, but refresh failed. Tap Retry.');
      }
    } catch (error, stackTrace) {
      debugPrint('Save failed: $error\n$stackTrace');

      if (!mounted) return;

      // Preserve form when the write fails
      showMessage('Could not save guest. Please try again. $error');
    } finally {
      if (mounted) {
        setState(() {
          isBusy = false;
        });
      }
    }
  }

  //Edit Guest
  void editGuest(Map<String, dynamic> guest) {
    if (isBusy) return;

    setState(() {
      editingId = guest[DatabaseHelper.columnId] as int;
      nameController.text = guest[DatabaseHelper.columnName] as String;
      ageController.text = guest[DatabaseHelper.columnAge].toString();
    });
  }

  // Clear form after successful database operation
  void clearForm() {
    setState(() {
      editingId = null;
      nameController.clear();
      ageController.clear();
    });

    formKey.currentState?.reset();
  }

  // Cancel Edit
  void cancelEdit() {
    if (isBusy) return;

    clearForm();
  }

  //delete guest
  Future<void> deleteGuest(int selectedId, String name) async {
    if (isBusy) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Guest'),
          content: Text('Delete $name (ID: $selectedId)?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true || isBusy) return;

    setState(() {
      isBusy = true;
    });

    try {
      final deleted = await widget.helper.delete(selectedId);

      if (!mounted) return;

      if (deleted == 0) {
        showMessage('Guest ID $selectedId no longer exists. Reloading roster.');
        await loadGuests();
        return;
      }

      // Clear editing only if deleted row was selected
      if (editingId == selectedId) {
        clearForm();
      }

      final refreshed = await loadGuests();

      if (!mounted) return;

      if (refreshed) {
        showMessage('Guest ID $selectedId deleted. Rows affected: $deleted');
      } else {
        showMessage(
          'Guest ID $selectedId deleted, but refresh failed. Tap Retry.',
        );
      }
    } catch (error, stackTrace) {
      debugPrint('Delete failed: $error\n$stackTrace');

      if (!mounted) return;

      showMessage('Could not delete guest. Please try again. $error');
    } finally {
      if (mounted) {
        setState(() {
          isBusy = false;
        });
      }
    }
  }

  //dispose controllers
  @override
  void dispose() {
    nameController.dispose();
    ageController.dispose();
    super.dispose();
  }

  //build User Interface
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fall Festival Roster')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Form(
              key: formKey,
              child: Column(
                children: [
                  // NAME FIELD
                  TextFormField(
                    controller: nameController,
                    enabled: !isBusy,
                    decoration: const InputDecoration(
                      labelText: 'Guest Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: validateName,
                  ),

                  const SizedBox(height: 12),

                  // AGE FIELD
                  TextFormField(
                    controller: ageController,
                    enabled: !isBusy,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Age',
                      border: OutlineInputBorder(),
                    ),
                    validator: validateAge,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ADD / SAVE / CANCEL
            Row(
              children: [
                ElevatedButton(
                  onPressed: isBusy ? null : saveGuest,
                  child: Text(editingId == null ? 'Add Guest' : 'Save Changes'),
                ),

                const SizedBox(width: 10),

                OutlinedButton(
                  onPressed: isBusy ? null : cancelEdit,
                  child: const Text('Cancel Edit'),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // RECORD COUNT AND REFRESH
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  errorMessage == null
                      ? 'Records: $recordCount'
                      : 'Records: unavailable',
                  style: const TextStyle(fontSize: 18),
                ),

                ElevatedButton.icon(
                  onPressed: isBusy ? null : refreshGuests,
                  icon: const Icon(Icons.refresh),
                  label: Text(errorMessage == null ? 'Refresh' : 'Retry'),
                ),
              ],
            ),

            const Divider(),

            // GUEST LIST
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : errorMessage != null
                  ? Center(
                      child: Text(errorMessage!, textAlign: TextAlign.center),
                    )
                  : guests.isEmpty
                  ? const Center(child: Text('No festival guests yet'))
                  : ListView.builder(
                      itemCount: guests.length,
                      itemBuilder: (context, index) {
                        final guest = guests[index];

                        final id = guest[DatabaseHelper.columnId] as int;
                        final name = guest[DatabaseHelper.columnName] as String;
                        final age = guest[DatabaseHelper.columnAge] as int;

                        return Card(
                          child: ListTile(
                            title: Text(name),
                            subtitle: Text('ID: $id | Age: $age'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // EDIT
                                IconButton(
                                  tooltip: 'Edit guest',
                                  icon: const Icon(Icons.edit),
                                  onPressed: isBusy
                                      ? null
                                      : () => editGuest(guest),
                                ),

                                // DELETE
                                IconButton(
                                  tooltip: 'Delete guest',
                                  icon: const Icon(Icons.delete),
                                  onPressed: isBusy
                                      ? null
                                      : () => deleteGuest(id, name),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

//Part 2 new FolderListScreen
class FolderListScreen extends StatefulWidget {
  final DatabaseHelper helper;

  const FolderListScreen({super.key, required this.helper});

  @override
  State<FolderListScreen> createState() => _FolderListScreenState();
}

class _FolderListScreenState extends State<FolderListScreen> {
  List<Folder> folders = [];

  bool isLoading = true;
  bool isBusy = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadFolders();
  }

  //show a feedback message
  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  //read folder records from SQLite database
  Future<void> loadFolders() async {
    if (isBusy) return;

    setState(() {
      isLoading = true;
      isBusy = true;
    });

    try {
      final rows = await widget.helper.getFoldersWithCounts();

      if (!mounted) return;

      setState(() {
        folders = rows;
        errorMessage = null;
      });
    } catch (error, stackTrace) {
      debugPrint('Load folders failed: $error\n$stackTrace');

      if (!mounted) return;

      setState(() {
        errorMessage = 'Could not load folders: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
          isBusy = false;
        });
      }
    }
  }

  Future<void> addFolder() async {
    if (isBusy) return;

    String folderName = '';
    String? validationError;
    bool isSaving = false;

    final newId = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Folder'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    enabled: !isSaving,
                    decoration: InputDecoration(
                      labelText: 'Folder Name',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      folderName = value;
                    },
                  ),

                  if (validationError != null) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        validationError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ],
              ),

              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),

                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final name = folderName.trim();

                          if (name.isEmpty) {
                            setDialogState(() {
                              validationError = 'Folder name cannot be blank.';
                            });
                            return;
                          }

                          setDialogState(() {
                            isSaving = true;
                            validationError = null;
                          });

                          try {
                            final id = await widget.helper.insertFolder(name);

                            if (!dialogContext.mounted) return;

                            Navigator.pop(dialogContext, id);
                          } catch (error, stackTrace) {
                            debugPrint(
                              'Insert folder failed: $error\n$stackTrace',
                            );

                            if (!dialogContext.mounted) return;

                            setDialogState(() {
                              validationError =
                                  'Could not create folder. '
                                  'The name may already exist.';
                              isSaving = false;
                            });
                          }
                        },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted || newId == null) return;

    await loadFolders();

    if (!mounted) return;

    if (errorMessage == null) {
      showMessage('Folder created successfully. ID: $newId');
    } else {
      showMessage('Folder saved, but refresh failed. Tap Retry.');
    }
  }

  Future<void> deleteFolder(Folder folder) async {
    if (isBusy || folder.id == null) return;

    // Ask the user to confirm deletion
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Folder'),
          content: Text('Delete "${folder.name}" and all its cards?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true || isBusy) return;

    setState(() {
      isBusy = true;
    });

    int? affected;

    try {
      // Delete folder by its integer ID
      affected = await widget.helper.deleteFolder(folder.id!);
    } catch (error, stackTrace) {
      debugPrint('Delete folder failed: $error\n$stackTrace');

      if (mounted) {
        showMessage('Could not delete folder: $error');
      }
    } finally {
      if (mounted) {
        setState(() {
          isBusy = false;
        });
      }
    }

    if (!mounted || affected == null) return;

    await loadFolders();

    if (!mounted) return;

    if (errorMessage != null) {
      showMessage('Delete completed, but refresh failed. Tap Retry.');
    } else if (affected == 0) {
      showMessage('Folder no longer exists. Rows affected: 0');
    } else {
      showMessage('Folder deleted. Rows affected: $affected');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Card Catalogue'),
        actions: [
          IconButton(
            tooltip: 'Guest Roster',
            icon: const Icon(Icons.people),
            onPressed: isBusy
                ? null
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            FallFestivalRoster(helper: widget.helper),
                      ),
                    );
                  },
          ),

          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: isBusy ? null : loadFolders,
          ),
        ],
      ),

      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(errorMessage!, textAlign: TextAlign.center),
                  ElevatedButton(
                    onPressed: isBusy ? null : loadFolders,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : folders.isEmpty
          ? const Center(child: Text('No folders yet'))
          : ListView.builder(
              itemCount: folders.length,
              itemBuilder: (context, index) {
                final folder = folders[index];

                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.folder),
                    title: Text(folder.name),
                    subtitle: Text(
                      'ID: ${folder.id} | '
                      '${folder.cardCount} cards',
                    ),

                    trailing: IconButton(
                      tooltip: 'Delete folder',
                      icon: const Icon(Icons.delete),
                      onPressed: isBusy ? null : () => deleteFolder(folder),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: isBusy ? null : addFolder,
        icon: const Icon(Icons.add),
        label: const Text('Add Folder'),
      ),
    );
  }
}
