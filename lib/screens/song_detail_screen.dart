// lib/screens/song_detail_screen.dart

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:pfa/config/api_config.dart';
import 'package:provider/provider.dart';

import '../models/song.dart';
import '../providers/auth_provider.dart';
import '../providers/interaction_provider.dart';
// import '../providers/song_provider.dart'; // SongProvider n'est pas directement utilisé ici pour les recommandations
import '../services/ApiService.dart'; // Importer ApiService
import '../services/audio_player_service.dart';
import '../utils/helpers.dart';
import '../widgets/song_detail/comment_section_widget.dart';
import '../widgets/song_detail/reaction_bar_widget.dart';
// import '../widgets/home/song_list_item_widget.dart'; // Non réutilisé pour les recommandations

class SongDetailScreen extends StatefulWidget {
  static const routeName = '/song-detail';
  final Song song;
  final bool focusComments;
  final bool focusReactions;

  const SongDetailScreen({
    super.key,
    required this.song,
    this.focusComments = false,
    this.focusReactions = false,
  });

  @override
  State<SongDetailScreen> createState() => _SongDetailScreenState();
}

class _SongDetailScreenState extends State<SongDetailScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _commentsExpansionTileKey = GlobalKey();
  final GlobalKey _reactionsSectionKey = GlobalKey();
  final GlobalKey _recommendationsSectionKey = GlobalKey(); // Clé pour la nouvelle section

  // État pour les recommandations
  List<Song> _recommendedSongs = [];
  bool _isLoadingRecommendations = false;
  String? _recommendationsError;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {

        Provider.of<InteractionProvider>(context, listen: false)
            .setSongId(widget.song.id, forceRefresh: true);

        _fetchRecommendations(); // Appeler pour charger les recommandations

        if (widget.focusComments || widget.focusReactions) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _scrollToSection(
                  widget.focusComments ? _commentsExpansionTileKey : _reactionsSectionKey);
            }
          });
        }
      }
    });
  }

  Future<void> _fetchRecommendations() async {
    if (!mounted) return;
    setState(() {
      _isLoadingRecommendations = true;
      _recommendationsError = null;
    });
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final recommendations = await apiService.fetchRecommendedSongs(widget.song.id, authToken: Provider.of<AuthProvider>(context, listen: false).token);
      if (mounted) {
        setState(() {
          _recommendedSongs = recommendations;
          _isLoadingRecommendations = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _recommendationsError = e.toString();
          _isLoadingRecommendations = false;
        });
      }
    }
  }

  void _scrollToSection(GlobalKey key) {
    final context = key.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        alignment: 0.1, // Scroll to near the top of the section
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final audioPlayerService = Provider.of<AudioPlayerService>(context);
    final interactionProvider = Provider.of<InteractionProvider>(context);

    final bool isPlayingThisSong =
        audioPlayerService.currentSong?.id == widget.song.id &&
            audioPlayerService.isPlaying;
    final bool isPausedOnThisSong =
        audioPlayerService.currentSong?.id == widget.song.id &&
            audioPlayerService.playerState == PlayerState.paused;
    final bool isThisSongLoadedInPlayer =
        audioPlayerService.currentSong?.id == widget.song.id;

    final String coverImageUrl = '${API_BASE_URL}/api/songs/${widget.song.id}/cover';

    int displayCommentCount = interactionProvider.isLoadingComments && interactionProvider.comments.isEmpty
        ? widget.song.commentCount // Fallback to initial count if loading and no comments fetched yet
        : interactionProvider.comments.length; // Use actual fetched comments length

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: <Widget>[
          SliverAppBar(
            expandedHeight: MediaQuery.of(context).size.width * 0.75, // Responsive height
            pinned: true,
            floating: false,
            elevation: 2.0,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.song.title,
                style: TextStyle(
                  fontSize: 16.0,
                  color: Colors.white,
                  shadows: <Shadow>[
                    Shadow(
                      offset: const Offset(0.0, 1.0),
                      blurRadius: 3.0,
                      color: Colors.black.withOpacity(0.5),
                    ),
                  ],
                ),
                overflow: TextOverflow.ellipsis,
              ),
              centerTitle: true, // Centre le titre
              background: Hero(
                tag: 'song_cover_${widget.song.id}',
                child: Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: NetworkImage(coverImageUrl),
                      fit: BoxFit.cover,
                      // Optional: Add a slight darken overlay for better title visibility
                      colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.3), BlendMode.darken),
                    ),
                  ),
                  child: Image.network( // Redundant if BoxDecoration.image is set, but kept for errorBuilder
                    coverImageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[350], // Placeholder color
                        child: Icon(Icons.music_note_rounded, size: 100, color: Colors.grey[600]),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate(
              [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Text(widget.song.artist,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.grey[800])),
                      ),
                      const SizedBox(height: 12),
                      _buildSongInfoCard(widget.song),
                      const SizedBox(height: 24),
                      _buildPlayerControls(context, audioPlayerService, isPlayingThisSong, isPausedOnThisSong, isThisSongLoadedInPlayer),
                      const SizedBox(height: 12),
                      _buildProgressSlider(context, audioPlayerService, isThisSongLoadedInPlayer),
                      const SizedBox(height: 30),

                      const Divider(thickness: 1),
                      _buildSectionHeader(context, 'Réactions', key: _reactionsSectionKey),
                      ReactionBarWidget(songId: widget.song.id),
                      const SizedBox(height: 24),

                      const Divider(thickness: 1),
                      Theme( // Remove divider from ExpansionTile itself
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          key: _commentsExpansionTileKey,
                          leading: Icon(
                            Icons.mode_comment_outlined,
                            color: Theme.of(context).iconTheme.color ?? Theme.of(context).primaryColor,
                          ),
                          title: Text(
                            'Commentaires ($displayCommentCount)',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          initiallyExpanded: widget.focusComments,
                          onExpansionChanged: (bool expanding) {
                            if (expanding) {
                              // Delay scroll to allow tile to expand
                              Future.delayed(const Duration(milliseconds: 250), () {
                                if (mounted) _scrollToSection(_commentsExpansionTileKey);
                              });
                            }
                          },
                          children: <Widget>[
                            Padding(
                              padding: const EdgeInsets.only(top: 0, left: 8.0, right: 8.0, bottom: 16.0),
                              child: CommentSectionWidget(songId: widget.song.id),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),

                      // --- NOUVELLE SECTION : RECOMMANDATIONS ---
                      const Divider(thickness: 1),
                      _buildSectionHeader(context, 'Recommandations', key: _recommendationsSectionKey),
                      _buildRecommendationsSection(),
                      const SizedBox(height: 30), // Espace en bas
                      // --- FIN SECTION RECOMMANDATIONS ---
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSongInfoCard(Song song) {
    return Card(
      elevation: 0.5, // Subtile elevation
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
        // side: BorderSide(color: Colors.grey.shade300, width: 0.5), // Optional border
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (song.album != null && song.album!.isNotEmpty)
              _buildInfoRow(Icons.album_outlined, 'Album', song.album!),
            _buildInfoRow(Icons.category_outlined, 'Genre', song.genre),
            if (song.createdAt != null) // Using createdAt as publication date on platform
              _buildInfoRow(Icons.calendar_today_outlined, 'Publié le', song.formattedPublicationDate),
            if (song.duration != null && song.duration! > 0)
              _buildInfoRow(Icons.timer_outlined, 'Durée', song.formattedDuration),
            if (song.viewCount != null)
              _buildInfoRow(Icons.visibility_outlined, 'Vues', song.formattedViewCount),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[700]),
          const SizedBox(width: 10),
          Text('$label: ', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[800])),
          Expanded(child: Text(value, style: TextStyle(color: Colors.grey[800]), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, {required Key key}) {
    return Padding(
      key: key,
      padding: const EdgeInsets.only(top: 16.0, bottom: 10.0), // Adjusted padding
      child: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildPlayerControls(BuildContext context, AudioPlayerService audioPlayerService, bool isPlaying, bool isPaused, bool isThisSongLoaded) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
            icon: const Icon(Icons.skip_previous_rounded, size: 38),
            tooltip: 'Précédent',
            onPressed: () {
              // TODO: Implement skip previous functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Fonctionnalité "Précédent" à implémenter')),
              );
            }),
        if (audioPlayerService.isLoading && isThisSongLoaded) // Show loader only if this specific song is loading
          const SizedBox(width: 60, height: 60, child: Center(child: CircularProgressIndicator(strokeWidth: 3)))
        else
          IconButton(
            iconSize: 60,
            tooltip: isPlaying ? 'Pause' : 'Lecture',
            icon: Icon(
              isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
              color: Theme.of(context).primaryColor,
            ),
            onPressed: () {
              if (isPlaying) {
                audioPlayerService.pause();
              } else if (isPaused && isThisSongLoaded) { // Resume if paused on this song
                audioPlayerService.resume();
              } else { // Play (or replay/restart if it's this song but stopped, or play different song)
                audioPlayerService.play(widget.song);
              }
            },
          ),
        IconButton(
            icon: const Icon(Icons.skip_next_rounded, size: 38),
            tooltip: 'Suivant',
            onPressed: () {
              // TODO: Implement skip next functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Fonctionnalité "Suivant" à implémenter')),
              );
            }),
      ],
    );
  }

  Widget _buildProgressSlider(BuildContext context, AudioPlayerService audioPlayerService, bool isThisSongLoaded) {
    // The if(false) block was removed as it was dead code.
    // The logic below handles displaying the slider or a progress indicator.

    final double currentMs = isThisSongLoaded ? audioPlayerService.currentPosition.inMilliseconds.toDouble() : 0.0;
    final double totalMs = isThisSongLoaded ? audioPlayerService.totalDuration.inMilliseconds.toDouble() : 0.0;

    return Column(
      children: [
        if (isThisSongLoaded && totalMs > 0) // Show slider if this song is loaded and has a duration
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3.0,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7.0, elevation: 2.0),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
              activeTrackColor: Theme.of(context).primaryColor,
              inactiveTrackColor: Theme.of(context).primaryColor.withOpacity(0.3),
              thumbColor: Theme.of(context).primaryColor,
            ),
            child: Slider(
              value: currentMs.clamp(0.0, totalMs), // totalMs is guaranteed > 0 here
              min: 0.0,
              max: totalMs,
              onChanged: (value) {
                final position = Duration(milliseconds: value.toInt());
                audioPlayerService.seek(position);
              },
            ),
          )
        else // Show a generic progress indicator or disabled slider if not this song, or no duration
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14.0), // Approximate height of Slider
            child: LinearProgressIndicator(
              value: (isThisSongLoaded && audioPlayerService.isLoading) ? null : 0, // Indeterminate if loading this song
              valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor.withOpacity(0.5)),
              backgroundColor: Colors.grey[300],
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(isThisSongLoaded ? formatDuration(audioPlayerService.currentPosition) : formatDuration(Duration.zero), style: Theme.of(context).textTheme.bodySmall),
              Text(isThisSongLoaded ? formatDuration(audioPlayerService.totalDuration) : widget.song.formattedDuration, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }

  // --- NOUVEAU WIDGET POUR LA SECTION RECOMMANDATIONS ---
  Widget _buildRecommendationsSection() {
    if (_isLoadingRecommendations) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(16.0),
        child: CircularProgressIndicator(),
      ));
    }

    if (_recommendationsError != null) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text("Erreur chargement recommandations: $_recommendationsError", style: TextStyle(color: Theme.of(context).colorScheme.error)),
      ));
    }

    if (_recommendedSongs.isEmpty) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Text("Aucune recommandation pour le moment."),
      ));
    }

    return SizedBox(
      height: 180, // Hauteur fixe pour la liste horizontale
      child: ListView.builder(
        key: const PageStorageKey<String>('recommendationsList'), // Pour la mémorisation du scroll
        scrollDirection: Axis.horizontal,
        itemCount: _recommendedSongs.length,
        itemBuilder: (ctx, index) {
          final recommendedSong = _recommendedSongs[index];
          final String recommendedCoverImageUrl = '${API_BASE_URL}/api/songs/${recommendedSong.id}/cover';

          return SizedBox( // Donner une largeur fixe aux items pour le scroll horizontal
            width: MediaQuery.of(context).size.width * 0.4, // 40% de la largeur de l'écran
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              clipBehavior: Clip.antiAlias, // Pour que le borderRadius du Card affecte l'image
              child: InkWell(
                onTap: () {
                  // Naviguer vers les détails de la chanson recommandée
                  Navigator.of(context).pushReplacement(MaterialPageRoute(
                    builder: (context) => SongDetailScreen(song: recommendedSong),
                  ));
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded( // Pour que l'image prenne la hauteur disponible
                      child: Image.network(
                        recommendedCoverImageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity, // Assure que l'image remplit la largeur
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey[200],
                          child: Center(child: Icon(Icons.music_note_rounded, color: Colors.grey[500], size: 40)),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6.0),
                      child: Text(
                        recommendedSong.title,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 6.0, right: 6.0, bottom: 6.0, top: 2.0),
                      child: Text(
                        recommendedSong.artist,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
// --- FIN DU NOUVEAU WIDGET ---
}