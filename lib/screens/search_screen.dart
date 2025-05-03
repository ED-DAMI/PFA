import 'package:flutter/material.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<String> _filterOptions = ['Artistes', 'Albums', 'Chansons', 'Genres'];
  String? _selectedFilter; // Can be used to store the selected filter

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recherche'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Search Field
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher artistes, chansons, albums...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30.0),
                  borderSide: BorderSide.none, // No border line
                ),
                filled: true, // Need to set filled to true for fillColor
                fillColor: Theme.of(context).colorScheme.surfaceVariant, // Background color
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
              ),
              onChanged: (value) {
                // TODO: Implement dynamic search results update
                print('Search query: $value');
                setState(() {
                  // Trigger rebuild to show results potentially
                });
              },
            ),
            const SizedBox(height: 16.0),

            // Filter Chips (Example)
            Wrap(
              spacing: 8.0, // Gap between adjacent chips.
              runSpacing: 4.0, // Gap between lines.
              children: _filterOptions.map((filter) {
                return FilterChip(
                  label: Text(filter),
                  selected: _selectedFilter == filter,
                  onSelected: (bool selected) {
                    setState(() {
                      if (selected) {
                        _selectedFilter = filter;
                        print('Filter selected: $_selectedFilter');
                        // TODO: Apply filter to search results
                      } else {
                        _selectedFilter = null; // Deselect if tapped again (optional)
                      }
                    });
                  },
                  // Customize chip appearance if needed
                  // selectedColor: Theme.of(context).colorScheme.primary,
                  // checkmarkColor: Theme.of(context).colorScheme.onPrimary,
                );
              }).toList(),
            ),
            const SizedBox(height: 20.0),

            // Dynamic Results Area
            Expanded(
              child: _searchController.text.isEmpty
                  ? const Center(child: Text('Commencez à taper pour rechercher.'))
                  : _buildSearchResults(), // Display results here
            ),
          ],
        ),
      ),
    );
  }

  // Placeholder for displaying search results
  Widget _buildSearchResults() {
    // TODO: Replace with actual search result fetching and display logic
    // Based on _searchController.text and _selectedFilter
    return ListView.builder(
      itemCount: 15, // Placeholder number of results
      itemBuilder: (context, index) {
        return ListTile(
          leading: const Icon(Icons.music_note), // Example icon
          title: Text('Résultat de recherche ${index + 1}'),
          subtitle: Text('Type: ${_selectedFilter ?? "Tout"}'),
          onTap: () {
            // TODO: Navigate to the specific item (artist, album, song)
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Tapped search result ${index + 1}')),
            );
          },
        );
      },
    );
  }
}