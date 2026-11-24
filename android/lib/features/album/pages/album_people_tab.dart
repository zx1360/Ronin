import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/album/models/ai_search_models.dart';
import 'package:torrid/features/album/providers/album_providers.dart';
import 'package:torrid/features/album/services/ai_api_service.dart';
import 'package:torrid/providers/api_client/api_client_provider.dart';

class AlbumPeopleTab extends ConsumerWidget {
  const AlbumPeopleTab({super.key, required this.onPerson});
  final ValueChanged<AiPerson> onPerson;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final people = ref.watch(albumPeopleProvider);
    final api = ref.watch(apiClientManagerProvider);
    return people.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(aiFriendlyError(error), textAlign: TextAlign.center),
            ),
            TextButton(
              onPressed: () => ref.invalidate(albumPeopleProvider),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
      data: (persons) => RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(albumPeopleProvider);
          try {
            await ref.read(albumPeopleProvider.future);
          } catch (_) {}
        },
        child: persons.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('暂无人物分组')),
                  ),
                ],
              )
            : GridView.builder(
                key: const PageStorageKey('album-people'),
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(10),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 140,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.78,
                ),
                itemCount: persons.length,
                itemBuilder: (context, index) {
                  final person = persons[index];
                  return InkWell(
                    onTap: () => onPerson(person),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: person.coverMediaId == null
                                ? const _PersonPlaceholder()
                                : CachedNetworkImage(
                                    imageUrl:
                                        '${api.baseUrl}/API/gallery/${person.coverMediaId}/thumb',
                                    httpHeaders: api.headers,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) =>
                                        const _PersonPlaceholder(),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          person.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${person.faceCount} 个人脸',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _PersonPlaceholder extends StatelessWidget {
  const _PersonPlaceholder();

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: const Icon(Icons.person_outline),
  );
}
