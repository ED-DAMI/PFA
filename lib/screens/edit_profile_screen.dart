// lib/screens/edit_profile_screen.dart
import 'dart:io'; // Pour File
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:pfa/config/api_config.dart'; // Assurez-vous que cet import est correct
import '../providers/auth_provider.dart';
import '../models/user.dart';

class EditProfileScreen extends StatefulWidget {
  static const routeName = '/edit-profile';

  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _usernameController;

  File? _pickedImageFile;
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = false;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    // Accéder à currentUser une seule fois ici, car il ne changera pas pendant la durée de vie de cet écran.
    // Les changements seront reflétés dans UserProfileScreen après le pop().
    _currentUser = Provider.of<AuthProvider>(context, listen: false).currentUser;
    _usernameController = TextEditingController(text: _currentUser?.username ?? '');
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedImage = await _picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 800,
      );
      if (pickedImage == null) return;

      setState(() {
        _pickedImageFile = File(pickedImage.path);
      });
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la sélection de l\'image: $err'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showImageSourceActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choisir depuis la galerie'),
                onTap: () {
                  _pickImage(ImageSource.gallery);
                  Navigator.of(ctx).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Prendre une photo'),
                onTap: () {
                  _pickImage(ImageSource.camera);
                  Navigator.of(ctx).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submitProfile() async {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur: Utilisateur non chargé.'), backgroundColor: Colors.red),
      );
      return;
    }

    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }
    _formKey.currentState!.save(); // Pas strictement nécessaire si on utilise les controllers directement

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Appel réel à AuthProvider pour mettre à jour sur le serveur
      bool success = await authProvider.updateUserProfileOnServer(
        userId: _currentUser!.id,
        newUsername: _usernameController.text,
        avatarFile: _pickedImageFile, // Peut être null
      );

      if (!mounted) return; // Vérifier si le widget est toujours monté après l'appel async

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil mis à jour avec succès !'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop(); // Revenir à l'écran précédent
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            // Utiliser authProvider.error si vous avez un getter `error` dans AuthProvider
            content: Text(authProvider.error ?? 'Échec de la mise à jour du profil.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Une erreur inattendue est survenue: $error'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // _currentUser est initialisé dans initState, donc il ne devrait pas être null ici
    // sauf si initState n'a pas pu obtenir l'utilisateur.
    if (_currentUser == null) {
      // Cela pourrait arriver si AuthProvider n'a pas encore chargé currentUser au moment où cet écran est poussé.
      // Une meilleure approche serait de s'assurer que currentUser est disponible avant de naviguer ici,
      // ou d'afficher un CircularProgressIndicator ici et de charger _currentUser dans un FutureBuilder ou via listen:true.
      // Pour l'instant, on garde la vérification.
      return Scaffold(
          appBar: AppBar(
            title: const Text('Modifier le Profil'),
            backgroundColor: theme.primaryColor,
          ),
          body: const Center(child: Text('Erreur: Données utilisateur non disponibles.')));
    }

    // Construction de l'URL complète pour l'avatar actuel de l'utilisateur
    String? currentFullAvatarUrl;
    if (_currentUser!.avatarUrl != null && _currentUser!.avatarUrl!.isNotEmpty) {
      String relativePath = _currentUser!.avatarUrl!;
      if (API_BASE_URL.endsWith('/') && relativePath.startsWith('/')) {
        currentFullAvatarUrl = API_BASE_URL + relativePath.substring(1);
      } else if (!API_BASE_URL.endsWith('/') && !relativePath.startsWith('/')) {
        currentFullAvatarUrl = '$API_BASE_URL/$relativePath';
      } else {
        currentFullAvatarUrl = API_BASE_URL + relativePath;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Modifier le Profil'),
        backgroundColor: theme.primaryColor,
        iconTheme: IconThemeData(color: theme.colorScheme.onPrimary),
        titleTextStyle: TextStyle(color: theme.colorScheme.onPrimary, fontSize: 20, fontWeight: FontWeight.w500),
        actions: [
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: theme.colorScheme.onPrimary, strokeWidth: 2))),
            )
          else
            IconButton(
              icon: Icon(Icons.save_outlined, color: theme.colorScheme.onPrimary),
              onPressed: _submitProfile,
              tooltip: 'Enregistrer',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 70,
                    backgroundColor: theme.colorScheme.secondaryContainer.withOpacity(0.5),
                    child: _pickedImageFile != null
                        ? ClipOval( // Aperçu de la nouvelle image
                        child: Image.file(
                          _pickedImageFile!,
                          fit: BoxFit.cover,
                          width: 140, // 2 * radius
                          height: 140,
                        ))
                        : (currentFullAvatarUrl != null)
                        ? ClipOval( // Avatar actuel du serveur
                        child: Image.network(
                          currentFullAvatarUrl,
                          fit: BoxFit.cover,
                          width: 140,
                          height: 140,
                          loadingBuilder: (context, child, progress) =>
                          progress == null ? child : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          errorBuilder: (context, error, stackTrace) {
                            // print('EditProfileScreen - Error loading current avatar: $error');
                            return Icon(Icons.person_outline, size: 70, color: theme.colorScheme.onSecondaryContainer);
                          },
                        ))
                    // Placeholder si aucune image
                        : Icon(Icons.person_add_alt_1_outlined, size: 70, color: theme.colorScheme.onSecondaryContainer),
                  ),
                  Positioned(
                    right: 4, // Ajustement pour un meilleur visuel
                    bottom: 4,
                    child: Material(
                      color: theme.primaryColor,
                      shape: const CircleBorder(),
                      elevation: 2,
                      child: InkWell(
                        onTap: _isLoading ? null : () => _showImageSourceActionSheet(context),
                        customBorder: const CircleBorder(),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Icon(Icons.camera_alt, color: theme.colorScheme.onPrimary, size: 24),
                        ),
                      ),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: 'Nom d\'utilisateur',
                  hintText: 'Entrez votre nom d\'utilisateur',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  prefixIcon: const Icon(Icons.person_outline),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Veuillez entrer un nom d\'utilisateur.';
                  }
                  if (value.trim().length < 3) {
                    return 'Le nom d\'utilisateur doit contenir au moins 3 caractères.';
                  }
                  // Ajoutez d'autres validations si nécessaire (ex: caractères spéciaux)
                  return null;
                },
              ),
              const SizedBox(height: 32), // Espace avant un bouton de sauvegarde potentiel au bas
              // Vous pouvez garder le bouton de sauvegarde dans l'AppBar ou en ajouter un ici :
              // if (!_isLoading)
              //   ElevatedButton.icon(
              //     icon: const Icon(Icons.save_alt_outlined),
              //     label: const Text('Enregistrer les modifications'),
              //     onPressed: _submitProfile,
              //     style: ElevatedButton.styleFrom(
              //       backgroundColor: theme.primaryColor,
              //       foregroundColor: theme.colorScheme.onPrimary,
              //       padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
              //       textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
              //     ),
              //   )
              // else
              //   const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}