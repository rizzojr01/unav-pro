import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/destination_bloc.dart';
import '../bloc/destination_event.dart';
import '../bloc/destination_state.dart';

class DestinationPage extends StatefulWidget {
  const DestinationPage({super.key});

  @override
  State<DestinationPage> createState() => _DestinationPageState();
}

class _DestinationPageState extends State<DestinationPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Destination')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search for a destination...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onSubmitted: (value) {
                if (value.isNotEmpty) {
                  context.read<DestinationBloc>().add(
                    SearchDestinationsEvent(value),
                  );
                }
              },
            ),
          ),
          Expanded(
            child: BlocConsumer<DestinationBloc, DestinationState>(
              listener: (context, state) {
                if (state is DestinationSelected) {
                  // Navigate to navigation page with selected destination
                  Navigator.pushNamed(
                    context,
                    '/navigation',
                    arguments: state.destination,
                  );
                } else if (state is DestinationError) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(state.message)));
                }
              },
              builder: (context, state) {
                if (state is DestinationInitial) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.location_on, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('Search for a destination'),
                      ],
                    ),
                  );
                } else if (state is DestinationSearching) {
                  return const Center(child: CircularProgressIndicator());
                } else if (state is DestinationSearchSuccess) {
                  if (state.destinations.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No destinations found'),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: state.destinations.length,
                    itemBuilder: (context, index) {
                      final destination = state.destinations[index];
                      return ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.location_on),
                        ),
                        title: Text(destination.name),
                        subtitle: destination.address != null
                            ? Text(destination.address!)
                            : Text(
                                'Lat: ${destination.latitude.toStringAsFixed(4)}, '
                                'Lng: ${destination.longitude.toStringAsFixed(4)}',
                              ),
                        onTap: () {
                          context.read<DestinationBloc>().add(
                            SelectDestinationEvent(destination.id),
                          );
                        },
                      );
                    },
                  );
                } else if (state is DestinationError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(state.message),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            if (_searchController.text.isNotEmpty) {
                              context.read<DestinationBloc>().add(
                                SearchDestinationsEvent(_searchController.text),
                              );
                            }
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }
}
