// lib/screens/song_detail_screen.dart

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:pfa/config/api_config.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';

import '../models/song.dart';
import '../providers/auth_provider.dart';
import '../providers/interaction_provider.dart';
import '../services/ApiService.dart';
import '../services/audio_player_service.dart';
import '../utils/helpers.dart';
import '../widgets/song_detail/comment_section_widget.dart';
import '../widgets/song_detail/reactions_dialog_helper.dart';
import '../../utils/constants.dart';

// Added imports
import '../providers/playlist_provider.dart';
import '../models/playlist.dart';

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
        interactionProvider.setSongId(widget.song.id, forceRefresh: true).then((_) {
          if (mounted) {
            _handleInitialFocusOrAction();
          }
        });
        _fetchRecommendations();

        // It's also a good idea to ensure playlists are fetched if the user might access this feature.
        // However, PlaylistProvider itself handles its initialization state.
        // We can trigger a fetch in _showAddToPlaylistDialog if needed.
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isCommentsExpanded) {
          _scrollToSection(_commentsExpansionTileKey);
        }
      });
    }

    if (widget.openReactionsDialogOnLoad) {
      void checkReactionsAndOpenDialog() {
        if (!mounted) return;
        if (interactionProvider.currentSongId == widget.song.id &&
            interactionProvider.isReactionsInitializedForCurrentSong &&
            !interactionProvider.isLoadingReactions) {
          showReactionsPickerDialog(screenContext: context, songId: widget.song.id);
        } else if (interactionProvider.isLoadingReactions && interactionProvider.currentSongId == widget.song.id) {
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
      if(token!=null) {
        // Consider moving view increment logic to a more central place or ensuring it's idempotent.
        // For now, it's as per original code.
        await apiService.IncrmentView(widget.song.id,authToken: token); // Assuming IncrmentView -> incrementView
      }

      if (mounted) {
        setState(() {
          _recommendedSongs = recommendations;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _recommendationsError = e.toString();
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
        alignment: 0.1,
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

    if (interactionProvider.currentSongId == widget.song.id &&
        interactionProvider.isReactionsInitializedForCurrentSong &&
        !interactionProvider.isLoadingReactions) {
      showReactionsPickerDialog(screenContext: context, songId: widget.song.id);
    } else if (interactionProvider.isLoadingReactions && interactionProvider.currentSongId == widget.song.id) {
      showAppSnackBar(context, "Chargement des réactions...", isError: false);
    } else {
      if (interactionProvider.currentSongId != widget.song.id) {
        if (kDebugMode) {
          print("Open Dialog WARN: InteractionProvider not set for song ${widget.song.id}. Calling setSongId.");
        }
        interactionProvider.setSongId(widget.song.id, forceRefresh: true);
        showAppSnackBar(context, "Préparation des données de réactions...", isError: false);
      } else {
        showAppSnackBar(context, "Les données de réactions ne sont pas encore disponibles.", isError: true);
        if (!interactionProvider.isLoadingReactions && interactionProvider.error == null) {
          if (kDebugMode) {
            print("Open Dialog: Triggering fetchReactions as data was not ready.");
          }
          interactionProvider.fetchReactions();
        }
      }
    }
  }

  // New method to show playlists for adding the current song
  void _showAddToPlaylistDialog(BuildContext screenContext) {
    final playlistProvider = Provider.of<PlaylistProvider>(screenContext, listen: false);
    final authProvider = Provider.of<AuthProvider>(screenContext, listen: false);

    if (!authProvider.isAuthenticated) {
      showAppSnackBar(screenContext, "Connectez-vous pour ajouter aux playlists.", isError: true);
      return;
    }

    // Ensure playlists are loaded if not already.
    // PlaylistProvider.fetchPlaylists has its own internal guards.
    if (!playlistProvider.isInitialized && !playlistProvider.isLoadingList) {
      playlistProvider.fetchPlaylists();
    }

    showModalBottomSheet(
      context: screenContext,
      isScrollControlled: true, // Allows the sheet to take more height if needed
      builder: (dialogCtx) {
        return Consumer<PlaylistProvider>( // Use Consumer to react to loading/data changes
          builder: (context, pProvider, child) {
            Widget content;
            if (pProvider.isLoadingList && !pProvider.isInitialized) {
              content = const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              );
            } else if (pProvider.error != null && pProvider.playlists.isEmpty) {
              content = SizedBox(
                height: 200,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text("Erreur de chargement des playlists: ${pProvider.error}"),
                  ),
                ),
              );
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
                          Navigator.of(dialogCtx).pop();
                          // Note: The actual create playlist dialog is in UserProfileScreen.
                          // This button could navigate there or show a simpler message.
                          showAppSnackBar(screenContext, "Allez à votre profil pour créer une playlist.");
                        },
                      )
                    ],
                  ),
                ),
              );
            } else {
              content = ListView.builder(
                shrinkWrap: true, // Important for ListView in a Column/bottom sheet
                itemCount: pProvider.playlists.length,
                itemBuilder: (ctx, index) {
                  final playlist = pProvider.playlists[index];
                  final bool songAlreadyInPlaylist = playlist.songIds.contains(widget.song.id);

                  return ListTile(
                    leading: Icon(songAlreadyInPlaylist ? Icons.check_circle_outline : Icons.playlist_add_outlined,
                        color: songAlreadyInPlaylist ? Colors.green : null),
                    title: Text(playlist.name),
                    subtitle: Text("${playlist.songIds.length} chanson(s)"),
                    enabled: !songAlreadyInPlaylist && !pProvider.isModifyingItem,
                    trailing: songAlreadyInPlaylist
                        ? null // No trailing if song is already in playlist
                        : (pProvider.isModifyingItem // Show loader if any modification is ongoing
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.add_circle_outline)), // Icon to indicate "add" action
                    onTap: songAlreadyInPlaylist || pProvider.isModifyingItem
                        ? null
                        : () async {
                      Navigator.of(dialogCtx).pop(); // Close the bottom sheet

                      showAppSnackBar(
                          screenContext,
                          "Ajout de '${widget.song.title}' à '${playlist.name}'...",
                          isError: false,
                          //duration: const Duration(seconds: 2)
                      );

                      bool success = await pProvider.addSongToPlaylist(playlist.id, widget.song.id);

                      if (!screenContext.mounted) return;

                      if (success) {
                        showAppSnackBar(
                            screenContext,
                            "'${widget.song.title}' ajouté à '${playlist.name}' !",
                            isError: false,
                            //backgroundColor: Colors.green
                        );
                      } else {
                        showAppSnackBar(
                            screenContext,
                            pProvider.error ?? "Erreur lors de l'ajout.",
                            isError: true
                        );
                      }
                    },
                  );
                },
              );
            }

            return Padding( // Wrap content in Padding for viewInsets and overall padding
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(dialogCtx).viewInsets.bottom, // For keyboard
                  top: 16, left: 16, right: 16
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    "Ajouter à...",
                    style: Theme.of(dialogCtx).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  Flexible(child: content), // Make the list scrollable if content is too long
                  const SizedBox(height: 16), // Padding at the bottom
                ],
              ),
            );
          },
        );
      },
    );
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

    if (interactionProvider.currentSongId == widget.song.id &&
        interactionProvider.isReactionsInitializedForCurrentSong) {
      currentUserEmojiReaction = interactionProvider.currentUserReactionEmoji;
      userHasReacted = currentUserEmojiReaction != null;
    }

    Widget reactionIconWidget;
    Color? reactionIconColor = Theme.of(context).iconTheme.color;

    if (userHasReacted && currentUserEmojiReaction != null) {
      reactionIconWidget = Text(
        currentUserEmojiReaction,
        style: TextStyle(fontSize: 26, color: reactionIconColor),
      );
      if (currentUserEmojiReaction == '❤️') {
        reactionIconColor = Colors.redAccent;
        reactionIconWidget = Text(
          currentUserEmojiReaction,
          style: TextStyle(fontSize: 26, color: reactionIconColor),
        );
      }
    } else {
      reactionIconWidget = Icon(
        Icons.sentiment_satisfied_alt_outlined,
        color: reactionIconColor,
      );
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
                child: IconButton(
                  icon: reactionIconWidget,
                  iconSize: 28,
                  color: reactionIconColor,
                  onPressed: () {
                    _openReactionsDialog(context, interactionProvider);
                  },
                  onLongPress: () {
                    _openReactionsDialog(context, interactionProvider);
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.skip_previous_rounded),
                iconSize: 38,
                tooltip: "Précédent",
                onPressed: () {
                  showAppSnackBar(context, 'Précédent : Non implémenté');
                },
              ),
              if (audioPlayerService.isLoading && isThisSongLoadedInPlayer)
                SizedBox(
                    width: 70,
                    height: 70,
                    child: Center(child: CircularProgressIndicator(strokeWidth: 3.0, color: Theme.of(context).primaryColor)))
              else
                IconButton(
                  icon: Icon(
                    isPlayingThisSong ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                  ),
                  iconSize: 70,
                  color: Theme.of(context).primaryColor,
                  tooltip: isPlayingThisSong ? "Pause" : "Lecture",
                  onPressed: () {
                    if (isPlayingThisSong) {
                      audioPlayerService.pause();
                    } else if (isPausedOnThisSong) {
                      audioPlayerService.resume();
                    } else {
                      if(interactionProvider.currentSongId != widget.song.id) {
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
                onPressed: () {
                  showAppSnackBar(context, 'Suivant : Non implémenté');
                },
              ),
              IconButton( // This is the "More Options" button
                icon: const Icon(Icons.more_horiz_rounded),
                iconSize: 28,
                tooltip: "Plus d'options",
                onPressed: () {
                  showModalBottomSheet(
                    context: context, // Screen's context
                    builder: (ctx) => Wrap( // ctx is for the modal sheet
                      children: <Widget>[
                        ListTile(
                          leading: const Icon(Icons.playlist_add),
                          title: const Text('Ajouter à une playlist'),
                          onTap: () {
                            Navigator.of(ctx).pop(); // Close this "More Options" sheet
                            _showAddToPlaylistDialog(context); // Show the "Add to Playlist" sheet
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.share),
                          title: const Text('Partager'),
                          onTap: () {
                            Navigator.of(ctx).pop();
                            showAppSnackBar(context, 'Partager: Non implémenté');
                          },
                        ),
                        if (widget.song.album != null && widget.song.album!.isNotEmpty)
                          ListTile(
                            leading: const Icon(Icons.album_outlined),
                            title: Text('Album: ${widget.song.album}'),
                            onTap: () { Navigator.of(ctx).pop();},
                          ),
                        ListTile(
                          leading: const Icon(Icons.info_outline),
                          title: const Text('Détails (Genre, Date...)'),
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
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.song.album != null && widget.song.album!.isNotEmpty)
                _buildInfoRowDialog(Icons.album_outlined, 'Album', widget.song.album!),
              _buildInfoRowDialog(Icons.category_outlined, 'Genre', widget.song.genre),
              if (widget.song.createdAt != null)
                _buildInfoRowDialog(Icons.calendar_today_outlined, 'Publié le', widget.song.formattedPublicationDate),
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
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.secondary),
          const SizedBox(width: 12),
          Text('$label: ', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w500)),
          Expanded(child: Text(value, style: Theme.of(context).textTheme.bodyMedium, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _buildActualProgressSlider(BuildContext context, AudioPlayerService audioPlayerService, bool isThisSongLoaded) {
    final currentMs = isThisSongLoaded ? audioPlayerService.currentPosition.inMilliseconds.toDouble() : 0.0;
    final totalMs = isThisSongLoaded && audioPlayerService.totalDuration > Duration.zero
        ? audioPlayerService.totalDuration.inMilliseconds.toDouble()
        : (widget.song.duration?.toDouble() ?? 1.0);

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
            max: totalMs > 0 ? totalMs : 1.0,
            onChanged: (isThisSongLoaded && totalMs > 0) ? (value) {
              audioPlayerService.seek(Duration(milliseconds: value.toInt()));
            } : null,
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
              Text(
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
    if (interactionProvider.currentSongId != widget.song.id ||
        (!interactionProvider.isReactionsInitializedForCurrentSong && !interactionProvider.isLoadingReactions)) {
      return const SizedBox.shrink();
    }

    if (interactionProvider.isLoadingReactions && !interactionProvider.isReactionsInitializedForCurrentSong) {
      return const Center(child: Padding(
        padding: EdgeInsets.symmetric(vertical: 16.0),
        child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5)),
      ));
    }

    final reactionCounts = interactionProvider.reactionCounts;
    final List<Widget> reactionChips = [];
    int totalReactions = 0;

    kReactionEmojis.forEach((emoji) {
      final count = reactionCounts[emoji] ?? 0;
      totalReactions += count;
      if (count > 0) {
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
              child: Text(
                "Soyez le premier à réagir !",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      child: Wrap(
        spacing: 6.0,
        runSpacing: 4.0,
        alignment: WrapAlignment.center,
        children: reactionChips.isEmpty && !interactionProvider.isLoadingReactions ? [] : reactionChips,
      ),
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
                Text(
                  'Comments',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Text(
                  (interactionProvider.isLoadingComments && !interactionProvider.isCommentsInitializedForCurrentSong && interactionProvider.currentSongId == widget.song.id)
                      ? "(...)"
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
                    backgroundColor: Colors.black87, // Consider Theme.of(context).colorScheme.primary for consistency
                    child: Text(
                      latestComment.author.isNotEmpty ? latestComment.author[0].toUpperCase() : "?",
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      latestComment.text,
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
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
      return Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text("Erreur recommandations: $_recommendationsError", style: TextStyle(color: Colors.red[700]))));
    }
    if (_recommendedSongs.isEmpty) {
      return const SizedBox.shrink(); // No recommendations to show
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 12.0),
          child: Text(
            "You might also like",
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(
          height: 190, // Adjust height as needed
          child: ListView.builder(
            key: const PageStorageKey<String>('recommendationsListNewUI'),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            itemCount: _recommendedSongs.length,
            itemBuilder: (ctx, index) {
              final rSong = _recommendedSongs[index];
              final String rCoverUrl = '${API_BASE_URL}/api/songs/${rSong.id}/cover'; // Use model's getter
              return Container(
                width: MediaQuery.of(context).size.width * 0.38, // Adjust width as needed
                margin: const EdgeInsets.symmetric(horizontal: 6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8.0),
                  onTap: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => SongDetailScreen(song: rSong))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AspectRatio(
                        aspectRatio: 1,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8.0),
                          child: Image.network(
                            rCoverUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceVariant,
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              child: Icon(Icons.music_note, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 40),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0, left: 2.0, right: 2.0),
                        child: Text(
                          rSong.title,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 2.0, left: 2.0, right: 2.0),
                        child: Text(
                          rSong.artist,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
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
    final audioPlayerService = Provider.of<AudioPlayerService>(context);
    final interactionProvider = Provider.of<InteractionProvider>(context);

    final bool isThisSongLoadedInPlayer = audioPlayerService.currentSong?.id == widget.song.id;
    final bool isPlayingThisSong = isThisSongLoadedInPlayer && audioPlayerService.isPlaying;
    final bool isPausedOnThisSong = isThisSongLoadedInPlayer && audioPlayerService.playerState == PlayerState.paused;

    final String coverImageUrl = '${API_BASE_URL}/api/songs/${widget.song.id}/cover'; // Use model's getter

    int displayCommentCount = widget.song.commentCount;
    if (interactionProvider.currentSongId == widget.song.id &&
        interactionProvider.isCommentsInitializedForCurrentSong &&
        !interactionProvider.isLoadingComments) {
      displayCommentCount = interactionProvider.comments.length;
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
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            surfaceTintColor: Colors.transparent,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundColor: Colors.black.withOpacity(0.35),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                  tooltip: "Retour",
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              titlePadding: const EdgeInsets.only(bottom: 16.0, left: 70, right: 70),
              title: Text(
                widget.song.title.toUpperCase(),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  shadows: [ const Shadow(blurRadius: 6.0, color: Colors.black87, offset: Offset(0, 1)) ],
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              background: Hero(
                tag: 'song_cover_${widget.song.id}',
                child: Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: NetworkImage(coverImageUrl),
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.30), BlendMode.darken),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 20.0),
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
                  Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      key: _commentsExpansionTileKey,
                      initiallyExpanded: _isCommentsExpanded,
                      onExpansionChanged: (expanding) {
                        setState(() => _isCommentsExpanded = expanding);
                        if (expanding) {
                          Future.delayed(const Duration(milliseconds: 150), () {
                            if (mounted) _scrollToSection(_commentsExpansionTileKey);
                          });
                        }
                      },
                      title: const SizedBox.shrink(), // Title is handled by _buildCommentsPreview
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: const EdgeInsets.only(bottom: 16.0),
                      children: <Widget>[
                        if (_isCommentsExpanded)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
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