// lib/screens/song_detail_screen.dart

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:pfa/config/api_config.dart'; // Assurez-vous que cette constante est bien définie
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart'; // Import pour la fonctionnalité de partage

import '../models/song.dart'; // Assurez-vous que Song a les getters formatés
import '../models/playlist.dart'; // Pour _showAddToPlaylistDialog
import '../providers/auth_provider.dart';
import '../providers/interaction_provider.dart';
import '../providers/playlist_provider.dart'; // Pour _showAddToPlaylistDialog
import '../widgets/services/ApiService.dart';
import '../widgets/services/audio_player_service.dart';
import '../utils/helpers.dart'; // Pour showAppSnackBar et formatDuration
import '../widgets/song_detail/comment_section_widget.dart'; // Widget à implémenter
import '../widgets/song_detail/reactions_dialog_helper.dart';
import '../../utils/constants.dart'; // Pour kReactionEmojis

class SongDetailScreen extends StatefulWidget {
  static const routeName = '/song-detail';
  final Song song;
  final bool focusComments;
  final bool openReactionsDialogOnLoad;

  const SongDetailScreen({
    super.key,
    required this.song,
    this.focusComments = false,
    this.openReactionsDialogOnLoad = false,
  });

  @override
  State<SongDetailScreen> createState() => _SongDetailScreenState();
}

class _SongDetailScreenState extends State<SongDetailScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _commentsExpansionTileKey = GlobalKey();
  final GlobalKey _recommendationsSectionKey = GlobalKey();

  List<Song> _recommendedSongs = [];
  bool _isLoadingRecommendations = false;
  String? _recommendationsError;

  bool _isCommentsExpanded = false;

  @override
  void initState() {
    super.initState();
    _isCommentsExpanded = widget.focusComments;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final interactionProvider = Provider.of<InteractionProvider>(context, listen: false);
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final apiService = Provider.of<ApiService>(context, listen: false);

        // Initialiser InteractionProvider pour la chanson actuelle
        interactionProvider.setSongId(widget.song.id, forceRefresh: true).then((_) {
          if (mounted) {
            _handleInitialFocusOrAction();
          }
        });

        _fetchRecommendations();

        // Incrémenter la vue si l'utilisateur est connecté
        // Une logique plus avancée pourrait vérifier si la vue a déjà été incrémentée pour cette chanson dans cette session
        // ou lier l'incrémentation à un temps de lecture minimal via AudioPlayerService.
        if (authProvider.isAuthenticated && authProvider.token != null) {
          apiService.incrementSongView(widget.song.id, authToken: authProvider.token!);
        }
      }
    });
  }

  void _handleInitialFocusOrAction() {
    if (!mounted) return;
    final interactionProvider = Provider.of<InteractionProvider>(context, listen: false);

    if (widget.focusComments) {
      if (!_isCommentsExpanded) {
        setState(() {
          _isCommentsExpanded = true;
        });
      }
      // S'assurer que l'ExpansionTile est rendu avant de scroller
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isCommentsExpanded) {
          _scrollToSection(_commentsExpansionTileKey);
        }
      });
    }

    if (widget.openReactionsDialogOnLoad) {
      // Attendre que InteractionProvider ait potentiellement chargé les réactions
      void checkReactionsAndOpenDialog() {
        if (!mounted) return;
        if (interactionProvider.currentSongId == widget.song.id &&
            interactionProvider.isReactionsInitializedForCurrentSong &&
            !interactionProvider.isLoadingReactions) {
          showReactionsPickerDialog(screenContext: context, songId: widget.song.id);
        } else if (interactionProvider.isLoadingReactions && interactionProvider.currentSongId == widget.song.id) {
          // Si en chargement, réessayer après un court délai
          Future.delayed(const Duration(milliseconds: 300), checkReactionsAndOpenDialog);
        }
      }
      checkReactionsAndOpenDialog();
    }
  }

  Future<void> _fetchRecommendations() async {
    if (!mounted) return;
    setState(() {
      _isLoadingRecommendations = true;
      _recommendationsError = null;
    });
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      final recommendations = await apiService.fetchRecommendedSongs(widget.song.id, authToken: token);

      if (mounted) {
        setState(() {
          _recommendedSongs = recommendations;
        });
      }
    } catch (e) {
      if (kDebugMode) print("Error fetching recommendations: $e");
      if (mounted) {
        setState(() {
          _recommendationsError = "Impossible de charger les recommandations.";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingRecommendations = false;
        });
      }
    }
  }

  void _scrollToSection(GlobalKey key) {
    final currentContext = key.currentContext;
    if (currentContext != null) {
      Scrollable.ensureVisible(
        currentContext,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        alignment: 0.1, // Scroller légèrement au-dessus pour la visibilité
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _openReactionsDialog(BuildContext context, InteractionProvider interactionProvider) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) {
      showAppSnackBar(context, "Connectez-vous pour voir ou ajouter des réactions !", isError: true);
      return;
    }

    // Logique pour s'assurer que InteractionProvider est prêt
    if (interactionProvider.currentSongId != widget.song.id) {
      if (kDebugMode) print("ReactionsDialog: InteractionProvider songId mismatch. Setting songId.");
      interactionProvider.setSongId(widget.song.id, forceRefresh: true).then((_) {
        if(mounted) _openReactionsDialog(context, interactionProvider); // Réessayer après setSongId
      });
      showAppSnackBar(context, "Préparation des réactions...", isError: false);
      return;
    }

    if (interactionProvider.isLoadingReactions) {
      showAppSnackBar(context, "Chargement des réactions...", isError: false);
      return;
    }

    if (!interactionProvider.isReactionsInitializedForCurrentSong) {
      interactionProvider.fetchReactions().then((_){ // Tenter de charger si non initialisé
        if(mounted) _openReactionsDialog(context, interactionProvider); // Réessayer
      });
      showAppSnackBar(context, "Chargement initial des réactions...", isError: false);
      return;
    }
    // Si tout est prêt :
    showReactionsPickerDialog(screenContext: context, songId: widget.song.id);
  }

  void _showAddToPlaylistDialog(BuildContext screenContext) {
    final playlistProvider = Provider.of<PlaylistProvider>(screenContext, listen: false);
    final authProvider = Provider.of<AuthProvider>(screenContext, listen: false);

    if (!authProvider.isAuthenticated) {
      showAppSnackBar(screenContext, "Connectez-vous pour ajouter aux playlists.", isError: true);
      return;
    }

    // S'assurer que les playlists sont chargées (PlaylistProvider devrait gérer l'état interne)
    if (!playlistProvider.isInitialized && !playlistProvider.isLoadingList) {
      playlistProvider.fetchPlaylists(); // Déclenche le fetch si nécessaire
    }

    showModalBottomSheet(
      context: screenContext,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (dialogCtx) {
        return Consumer<PlaylistProvider>(
          builder: (context, pProvider, child) {
            Widget content;
            if (pProvider.isLoadingList && !pProvider.isInitialized) {
              content = const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
            } else if (pProvider.error != null && pProvider.playlists.isEmpty) {
              content = SizedBox(height: 200, child: Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text("Erreur de chargement des playlists: ${pProvider.error}"))));
            } else if (pProvider.playlists.isEmpty) {
              content = SizedBox(
                height: 200,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text("Aucune playlist trouvée."),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        child: const Text("Créer une playlist"),
                        onPressed: () {
                          Navigator.of(dialogCtx).pop(); // Fermer le bottom sheet
                          // TODO: Naviguer vers UserProfileScreen ou implémenter un dialogue de création ici
                          showAppSnackBar(screenContext, "Allez à votre profil pour créer une playlist.");
                        },
                      )
                    ],
                  ),
                ),
              );
            } else {
              content = ListView.builder(
                shrinkWrap: true,
                itemCount: pProvider.playlists.length,
                itemBuilder: (ctx, index) {
                  final playlist = pProvider.playlists[index];
                  final bool songAlreadyInPlaylist = playlist.songIds.contains(widget.song.id);

                  return ListTile(
                    leading: Icon(songAlreadyInPlaylist ? Icons.check_circle_outline : Icons.playlist_add_outlined, color: songAlreadyInPlaylist ? Colors.green : Theme.of(dialogCtx).iconTheme.color),
                    title: Text(playlist.name),
                    subtitle: Text("${playlist.songIds.length} chanson(s)"),
                    enabled: !songAlreadyInPlaylist && !pProvider.isModifyingItem, // Désactiver si déjà dedans ou si une opération est en cours
                    trailing: songAlreadyInPlaylist
                        ? null
                        : (pProvider.modifyingPlaylistId == playlist.id && pProvider.isModifyingItem
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.add_circle_outline)),
                    onTap: songAlreadyInPlaylist || pProvider.isModifyingItem
                        ? null
                        : () async {
                      final success = await pProvider.addSongToPlaylist(playlist.id, widget.song.id);
                      if (!dialogCtx.mounted) return; // Vérifier avant d'interagir avec dialogCtx
                      Navigator.of(dialogCtx).pop(); // Fermer le bottom sheet après l'action

                      if (!screenContext.mounted) return; // Vérifier avant d'interagir avec screenContext
                      if (success) {
                        showAppSnackBar(screenContext, "'${widget.song.title}' ajouté à '${playlist.name}' !", isError: false, backgroundColor: Colors.green);
                      } else {
                        showAppSnackBar(screenContext, pProvider.error ?? "Erreur lors de l'ajout.", isError: true);
                      }
                    },
                  );
                },
              );
            }
            // Envelopper le contenu pour le padding et la gestion du clavier
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(dialogCtx).viewInsets.bottom + 16, // Pour le clavier et padding bas
                top: 20, left: 16, right: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text("Ajouter à une playlist", style: Theme.of(dialogCtx).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Flexible(child: SingleChildScrollView(child: content)), // Assurer le défilement si la liste est longue
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _shareSong() async {
    // Idéalement, vous auriez une URL "deep link" pour votre chanson.
    // Pour l'exemple, nous utilisons une URL générique.
    final String songDeepLink = "https://monapp.com/songs/${widget.song.id}"; // Remplacez par votre deep link
    final String shareText = "Écoute '${widget.song.title}' par ${widget.song.artist} sur MaSuperApp!\n$songDeepLink";

    try {
      await Share.share(shareText, subject: "Découvre cette chanson : ${widget.song.title}");
    } catch (e) {
      if (kDebugMode) print("Erreur de partage: $e");
      if (mounted) {
        showAppSnackBar(context, "Impossible de partager la chanson pour le moment.", isError: true);
      }
    }
  }

  Widget _buildSongTitleAndArtist(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          widget.song.title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          widget.song.artist,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerControlsAndProgress(
      BuildContext context,
      AudioPlayerService audioPlayerService,
      InteractionProvider interactionProvider,
      bool isPlayingThisSong,
      bool isPausedOnThisSong,
      bool isThisSongLoadedInPlayer,
      ) {
    String? currentUserEmojiReaction;
    bool userHasReacted = false;

    if (interactionProvider.currentSongId == widget.song.id && interactionProvider.isReactionsInitializedForCurrentSong) {
      currentUserEmojiReaction = interactionProvider.currentUserReactionEmoji;
      userHasReacted = currentUserEmojiReaction != null;
    }

    Widget reactionIconWidget;
    Color reactionIconColor = Theme.of(context).iconTheme.color ?? Colors.grey;

    if (userHasReacted && currentUserEmojiReaction != null) {
      reactionIconWidget = Text(currentUserEmojiReaction, style: TextStyle(fontSize: 26, color: (currentUserEmojiReaction == '❤️' ? Colors.redAccent : reactionIconColor)));
      if (currentUserEmojiReaction == '❤️') reactionIconColor = Colors.redAccent;
    } else {
      reactionIconWidget = Icon(Icons.sentiment_satisfied_alt_outlined, color: reactionIconColor);
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: _buildActualProgressSlider(context, audioPlayerService, isThisSongLoadedInPlayer),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Tooltip(
                message: userHasReacted ? "Modifier votre réaction / Voir réactions" : "Réagir / Voir réactions",
                child: IconButton(icon: reactionIconWidget, iconSize: 28, color: reactionIconColor, onPressed: () => _openReactionsDialog(context, interactionProvider)),
              ),
              IconButton(
                icon: const Icon(Icons.skip_previous_rounded),
                iconSize: 38,
                tooltip: "Précédent",
                onPressed: () => audioPlayerService.skipPrevious(),
              ),
              if (audioPlayerService.isLoading && isThisSongLoadedInPlayer)
                SizedBox(width: 70, height: 70, child: Center(child: CircularProgressIndicator(strokeWidth: 3.0, color: Theme.of(context).primaryColor)))
              else
                IconButton(
                  icon: Icon(isPlayingThisSong ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded),
                  iconSize: 70,
                  color: Theme.of(context).primaryColor,
                  tooltip: isPlayingThisSong ? "Pause" : (isPausedOnThisSong ? "Reprendre" : "Lecture"),
                  onPressed: () {
                    if (isPlayingThisSong) {
                      audioPlayerService.pause();
                    } else if (isPausedOnThisSong) {
                      audioPlayerService.resume();
                    } else {
                      if (interactionProvider.currentSongId != widget.song.id) {
                        interactionProvider.setSongId(widget.song.id, forceRefresh: false);
                      }
                      audioPlayerService.play(widget.song);
                    }
                  },
                ),
              IconButton(
                icon: const Icon(Icons.skip_next_rounded),
                iconSize: 38,
                tooltip: "Suivant",
                onPressed: () => audioPlayerService.skipNext(),
              ),
              IconButton(
                icon: const Icon(Icons.more_horiz_rounded),
                iconSize: 28,
                tooltip: "Plus d'options",
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                    builder: (ctx) => Wrap(
                      children: <Widget>[
                        ListTile(
                          leading: const Icon(Icons.playlist_add),
                          title: const Text('Ajouter à une playlist'),
                          onTap: () {
                            Navigator.of(ctx).pop();
                            _showAddToPlaylistDialog(context);
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.share_outlined),
                          title: const Text('Partager'),
                          onTap: () {
                            Navigator.of(ctx).pop();
                            _shareSong();
                          },
                        ),
                        if (widget.song.album != null && widget.song.album!.isNotEmpty)
                          ListTile(
                            leading: const Icon(Icons.album_outlined),
                            title: Text('Album: ${widget.song.album}'),
                            onTap: () { Navigator.of(ctx).pop(); /* TODO: Naviguer vers vue album */ },
                          ),
                        ListTile(
                          leading: const Icon(Icons.info_outline),
                          title: const Text('Détails de la chanson'),
                          onTap: () {
                            Navigator.of(ctx).pop();
                            _showMoreSongInfoDialog(context);
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showMoreSongInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Informations sur la chanson"),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.song.album != null && widget.song.album!.isNotEmpty)
                _buildInfoRowDialog(Icons.album_outlined, 'Album', widget.song.album!),
              _buildInfoRowDialog(Icons.category_outlined, 'Genre', widget.song.genre),
              if (widget.song.createdAt != null) // Assurez-vous que Song a `formattedPublicationDate`
                _buildInfoRowDialog(Icons.calendar_today_outlined, 'Publié le', widget.song.formattedPublicationDate),
              // Assurez-vous que Song a `formattedDuration` et `formattedViewCount`
              if (widget.song.duration != null && widget.song.duration! > 0)
                _buildInfoRowDialog(Icons.timer_outlined, 'Durée', widget.song.formattedDuration),
              if (widget.song.viewCount > 0)
                _buildInfoRowDialog(Icons.visibility_outlined, 'Vues', widget.song.formattedViewCount),
            ],
          ),
        ),
        actions: [TextButton(child: const Text("Fermer"), onPressed: () => Navigator.of(ctx).pop())],
      ),
    );
  }

  Widget _buildInfoRowDialog(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.secondary),
          const SizedBox(width: 12),
          Text('$label: ', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w500)),
          Expanded(child: Text(value, style: Theme.of(context).textTheme.bodyMedium, overflow: TextOverflow.visible)),
        ],
      ),
    );
  }

  Widget _buildActualProgressSlider(BuildContext context, AudioPlayerService audioPlayerService, bool isThisSongLoaded) {
    final currentMs = isThisSongLoaded ? audioPlayerService.currentPosition.inMilliseconds.toDouble() : 0.0;
    // Utiliser la durée de la chanson comme fallback si totalDuration n'est pas encore disponible
    final totalMs = isThisSongLoaded && audioPlayerService.totalDuration > Duration.zero
        ? audioPlayerService.totalDuration.inMilliseconds.toDouble()
        : (widget.song.duration != null ? Duration(seconds: widget.song.duration!).inMilliseconds.toDouble() : 1.0);


    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 2.5,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7.0, elevation: 1.0),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
            activeTrackColor: Theme.of(context).colorScheme.primary,
            inactiveTrackColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
            thumbColor: Theme.of(context).colorScheme.primary,
          ),
          child: Slider(
            value: currentMs.clamp(0.0, totalMs > 0 ? totalMs : 1.0),
            min: 0.0,
            max: totalMs > 0 ? totalMs : 1.0, // S'assurer que max n'est jamais 0
            onChanged: (isThisSongLoaded && totalMs > 0)
                ? (value) {
              audioPlayerService.seek(Duration(milliseconds: value.toInt()));
            }
                : null, // Désactiver si pas chargé ou durée inconnue
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isThisSongLoaded ? formatDuration(audioPlayerService.currentPosition) : "0:00",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              Text( // Utiliser formattedDuration du modèle Song comme fallback
                isThisSongLoaded && audioPlayerService.totalDuration > Duration.zero
                    ? formatDuration(audioPlayerService.totalDuration)
                    : widget.song.formattedDuration,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailedReactionsDisplay(BuildContext context, InteractionProvider interactionProvider) {
    if (interactionProvider.currentSongId != widget.song.id || (!interactionProvider.isReactionsInitializedForCurrentSong && !interactionProvider.isLoadingReactions)) {
      return const SizedBox.shrink(); // Ne rien afficher si pas pour cette chanson ou non initialisé
    }

    if (interactionProvider.isLoadingReactions && !interactionProvider.isReactionsInitializedForCurrentSong) {
      return const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 16.0), child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5))));
    }

    final reactionCounts = interactionProvider.reactionCounts;
    final List<Widget> reactionChips = [];
    int totalReactions = 0;

    kReactionEmojis.forEach((emoji) { // Utiliser kReactionEmojis pour un ordre constant
      final count = reactionCounts[emoji] ?? 0;
      totalReactions += count;
      if (count > 0) { // Afficher seulement les réactions qui ont un compte > 0
        reactionChips.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3.0),
            child: Chip(
              avatar: Text(emoji, style: const TextStyle(fontSize: 14)),
              label: Text(count.toString(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
              backgroundColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.75),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 3.0),
              labelPadding: const EdgeInsets.only(left: 0, right: 4.0),
              visualDensity: VisualDensity.compact,
              side: BorderSide.none,
              elevation: 0.5,
            ),
          ),
        );
      }
    });

    if (totalReactions == 0 && interactionProvider.isReactionsInitializedForCurrentSong && !interactionProvider.isLoadingReactions) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Center(
          child: InkWell(
            onTap: () => _openReactionsDialog(context, interactionProvider),
            borderRadius: BorderRadius.circular(8.0),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: Text("Soyez le premier à réagir !", style: TextStyle(color: Theme.of(context).colorScheme.primary, fontStyle: FontStyle.italic)),
            ),
          ),
        ),
      );
    }
    if (reactionChips.isEmpty) return const SizedBox.shrink(); // Si aucune réaction à afficher après le filtrage

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      child: Wrap(spacing: 6.0, runSpacing: 4.0, alignment: WrapAlignment.center, children: reactionChips),
    );
  }

  Widget _buildCommentsPreview(BuildContext context, InteractionProvider interactionProvider, int displayCommentCount) {
    final latestComment = (interactionProvider.currentSongId == widget.song.id &&
        interactionProvider.isCommentsInitializedForCurrentSong &&
        interactionProvider.comments.isNotEmpty)
        ? interactionProvider.comments.first
        : null;

    return InkWell(
      onTap: () {
        setState(() {
          _isCommentsExpanded = !_isCommentsExpanded;
        });
        if (_isCommentsExpanded) {
          Future.delayed(const Duration(milliseconds: 150), () {
            if (mounted) _scrollToSection(_commentsExpansionTileKey);
          });
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.chat_bubble_outline_rounded, size: 24, color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 10),
                Text('Commentaires', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Text(
                  (interactionProvider.isLoadingComments && !interactionProvider.isCommentsInitializedForCurrentSong && interactionProvider.currentSongId == widget.song.id)
                      ? "(Chargement...)"
                      : '($displayCommentCount)',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).hintColor),
                ),
                const Spacer(),
                Icon(_isCommentsExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_right, color: Theme.of(context).hintColor),
              ],
            ),
            if (latestComment != null && !_isCommentsExpanded) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer, // Ou une couleur basée sur l'avatar de l'utilisateur si disponible
                    child: Text(
                      latestComment.author.isNotEmpty ? latestComment.author[0].toUpperCase() : "?", // Supposant que Comment a authorUsername
                      style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(latestComment.text, style: Theme.of(context).textTheme.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationsSectionUI() {
    if (_isLoadingRecommendations) {
      return const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 40.0), child: CircularProgressIndicator()));
    }
    if (_recommendationsError != null) {
      return Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text(_recommendationsError!, style: TextStyle(color: Theme.of(context).colorScheme.error))));
    }
    if (_recommendedSongs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20.0),
        child: Center(child: Text("Aucune recommandation pour le moment.")),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 12.0),
          child: Text("Vous pourriez aussi aimer", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        ),
        SizedBox(
          height: 190,
          child: ListView.builder(
            key: const PageStorageKey<String>('recommendationsList'), // Clé pour la préservation de l'état de défilement
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            itemCount: _recommendedSongs.length,
            itemBuilder: (ctx, index) {
              final rSong = _recommendedSongs[index];
              // Supposer que Song a un getter `coverArtUrl` ou que vous construisez l'URL ici
              final String rCoverUrl = rSong.coverImageUrl ?? '${API_BASE_URL}/api/songs/${rSong.id}/cover';

              return Container(
                width: MediaQuery.of(context).size.width * 0.38,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8.0),
                  onTap: () {
                    // Utiliser push pour permettre le retour, ou pushReplacement si vous ne voulez pas empiler les écrans de détail.
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => SongDetailScreen(song: rSong)));
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AspectRatio(
                        aspectRatio: 1,
                        child: Hero( // Ajout d'un Hero tag pour une transition douce si possible
                          tag: 'song_cover_recommendation_${rSong.id}',
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8.0),
                            child: Image.network(
                              rCoverUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceVariant, borderRadius: BorderRadius.circular(8.0)),
                                child: Icon(Icons.music_note, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 40),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0, left: 2.0, right: 2.0),
                        child: Text(rSong.title, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 2.0, left: 2.0, right: 2.0),
                        child: Text(rSong.artist, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final audioPlayerService = Provider.of<AudioPlayerService>(context); // Listen true pour la réactivité de l'UI
    final interactionProvider = Provider.of<InteractionProvider>(context); // Listen true pour les réactions/commentaires

    final bool isThisSongLoadedInPlayer = audioPlayerService.currentSong?.id == widget.song.id;
    final bool isPlayingThisSong = isThisSongLoadedInPlayer && audioPlayerService.isPlaying;
    final bool isPausedOnThisSong = isThisSongLoadedInPlayer && audioPlayerService.playerState == PlayerState.paused;

    // Supposer que Song a un getter `coverArtUrl` ou que vous construisez l'URL ici
    final String coverImageUrl = widget.song.coverImageUrl ?? '${API_BASE_URL}/api/songs/${widget.song.id}/cover';

    // Calcul du nombre de commentaires à afficher
    int displayCommentCount = widget.song.commentCount; // Valeur par défaut du modèle
    if (interactionProvider.currentSongId == widget.song.id && interactionProvider.isCommentsInitializedForCurrentSong && !interactionProvider.isLoadingComments) {
      displayCommentCount = interactionProvider.comments.length; // Utiliser la longueur de la liste du provider si disponible
    }

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: <Widget>[
          SliverAppBar(
            expandedHeight: MediaQuery.of(context).size.height * 0.42,
            pinned: true,
            floating: false,
            elevation: 2.0,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor, // Pour une meilleure transition
            surfaceTintColor: Colors.transparent, // Pour enlever la teinte par défaut sur scroll
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundColor: Colors.black.withOpacity(0.45), // Fond légèrement plus opaque
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                  tooltip: "Retour",
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true, // Centrer le titre quand réduit
              titlePadding: const EdgeInsets.only(bottom: 16.0, left: 70, right: 70), // Padding pour le titre
              title: Text( // Titre visible quand l'appbar est réduite
                widget.song.title.toUpperCase(),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  shadows: [const Shadow(blurRadius: 8.0, color: Colors.black, offset: Offset(0, 2))], // Ombre plus prononcée
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              background: Hero(
                tag: 'song_cover_${widget.song.id}', // Hero tag pour la transition
                child: Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: NetworkImage(coverImageUrl),
                      fit: BoxFit.cover,
                      // Filtre pour assombrir l'image et rendre le texte plus lisible
                      colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.35), BlendMode.darken),
                    ),
                  ),
                  // Optionnel: Un léger gradient en bas pour améliorer la lisibilité du titre
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withOpacity(0.3)],
                        stops: const [0.5, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 20.0), // Espace après l'AppBar
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: _buildSongTitleAndArtist(context),
                  ),
                  const SizedBox(height: 16),
                  _buildPlayerControlsAndProgress(
                    context,
                    audioPlayerService,
                    interactionProvider,
                    isPlayingThisSong,
                    isPausedOnThisSong,
                    isThisSongLoadedInPlayer,
                  ),
                  _buildDetailedReactionsDisplay(context, interactionProvider),
                  const Divider(indent: 20, endIndent: 20, height: 12, thickness: 0.8),
                  _buildCommentsPreview(context, interactionProvider, displayCommentCount),
                  Theme( // Enlever le diviseur par défaut de ExpansionTile
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      key: _commentsExpansionTileKey,
                      initiallyExpanded: _isCommentsExpanded,
                      onExpansionChanged: (expanding) {
                        setState(() => _isCommentsExpanded = expanding);
                        if (expanding) { // Scroller quand on ouvre
                          Future.delayed(const Duration(milliseconds: 150), () {
                            if (mounted) _scrollToSection(_commentsExpansionTileKey);
                          });
                        }
                      },
                      title: const SizedBox.shrink(), // Le titre est géré par _buildCommentsPreview
                      tilePadding: EdgeInsets.zero, // Pas de padding pour le titre vide
                      childrenPadding: const EdgeInsets.only(bottom: 16.0),
                      children: <Widget>[
                        if (_isCommentsExpanded)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            // Le widget CommentSectionWidget doit être implémenté
                            // et gérer son propre état de chargement/affichage des commentaires.
                            child: CommentSectionWidget(songId: widget.song.id),
                          ),
                      ],
                    ),
                  ),
                  const Divider(indent: 20, endIndent: 20, height: 24, thickness: 0.8),
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0, bottom: 30.0),
                    key: _recommendationsSectionKey,
                    child: _buildRecommendationsSectionUI(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}