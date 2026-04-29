// Minimal demo app for firepack-generated code, runnable against the
// local Firebase emulator.
//
// Demonstrates the full path:
//   YAML spec  →  generated model (Post)
//              →  generated repository (PostRepository)
//              →  generated Riverpod provider (postWatchByOrgProvider)
//              →  hand-written UI consuming the provider.
//
// CRUD coverage:
//   • Read — postWatchByOrgProvider (stream-watched list)
//   • Create — repo.add(...) (FAB + Seed button)
//   • Update — repo.updateById(...) (tap a tile, edit, save)
//   • Delete — repo.deleteById(...) (trailing icon + confirm)
//
// Run order:
//   1) `just example-emulator-up` (other terminal)
//   2) `just example-run` (Chrome)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firepack/models/post.dart';
import 'firepack/models/enums.dart';
import 'firepack/repositories/post_repository.dart';

/// `demo-` prefix tells the Firebase emulator that no real Google
/// project exists — auth + Firestore work without `flutterfire configure`.
const _demoProjectId = 'demo-firepack';
const _demoOrgId = 'demo-org';
const _demoAuthorId = 'u-001';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: 'demo',
      appId: 'demo',
      messagingSenderId: 'demo',
      projectId: _demoProjectId,
    ),
  );
  // Web → 'localhost'; Android emulator → '10.0.2.2'; iOS sim/macOS → 'localhost'.
  final host = (defaultTargetPlatform == TargetPlatform.android && !kIsWeb)
      ? '10.0.2.2'
      : 'localhost';
  FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
  runApp(const ProviderScope(child: FirepackExampleApp()));
}

class FirepackExampleApp extends StatelessWidget {
  const FirepackExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'firepack example',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const PostsScreen(orgId: _demoOrgId),
    );
  }
}

/// Lists posts for one organisation, streamed via the firepack-generated
/// Riverpod provider. Edit the spec, run `firepack regen`, and this
/// screen recompiles against the new shape.
class PostsScreen extends ConsumerWidget {
  const PostsScreen({super.key, required this.orgId});

  final String orgId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(postWatchByOrgProvider(orgId));

    return Scaffold(
      appBar: AppBar(title: Text('Posts · $orgId')),
      body: postsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: _ErrorView(error: e)),
        data: (posts) => posts.isEmpty
            ? _EmptyState(orgId: orgId)
            : ListView.separated(
                itemCount: posts.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) => _PostTile(post: posts[i], orgId: orgId),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('New post'),
        onPressed: () => _openEditor(context, orgId: orgId),
      ),
    );
  }
}

Future<void> _openEditor(
  BuildContext context, {
  required String orgId,
  Post? existing,
}) async {
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => PostEditorScreen(orgId: orgId, existing: existing),
    ),
  );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 12),
          Text('$error', textAlign: TextAlign.center),
          const SizedBox(height: 12),
          const Text(
            'Is `firebase emulators:start` running on localhost:8080?',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends ConsumerWidget {
  const _EmptyState({required this.orgId});

  final String orgId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('No posts yet.'),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Seed demo data'),
            onPressed: () => _seedDemoPosts(ref, orgId),
          ),
          const SizedBox(height: 8),
          const Text(
            'Writes 3 posts via the generated PostRepository.add().',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Demonstrates the write-path through generated code: every call below
/// goes through `PostRepository.add()` → `_firestore.collection(…).set()`,
/// using the model's generated `toFirestore()` (DateTime → Timestamp).
/// `serverDefault: now` on `createdAt` means the seeded createdAts are
/// silently overridden by FieldValue.serverTimestamp() — by design.
Future<void> _seedDemoPosts(WidgetRef ref, String orgId) async {
  final repo = ref.read(postRepositoryProvider);
  final now = DateTime.now();
  final samples = [
    Post(
      id: 'p-001',
      organizationId: orgId,
      authorId: _demoAuthorId,
      title: 'Hello from firepack',
      body: 'This row landed via the generated PostRepository.',
      status: PostStatus.published,
      createdAt: now.subtract(const Duration(hours: 2)),
      publishedAt: now.subtract(const Duration(hours: 2)),
    ),
    Post(
      id: 'p-002',
      organizationId: orgId,
      authorId: _demoAuthorId,
      title: 'Spec → model → repo',
      body: 'Edit example/firepack.yaml, run `just example-regen`, '
          'and the new shape flows all the way to this list.',
      status: PostStatus.draft,
      createdAt: now.subtract(const Duration(hours: 1)),
    ),
    Post(
      id: 'p-003',
      organizationId: orgId,
      authorId: 'u-002',
      title: 'Archived sample',
      body: 'Status enum (PostStatus) is generated from the spec too.',
      status: PostStatus.archived,
      createdAt: now,
    ),
  ];
  for (final post in samples) {
    await repo.add(post);
  }
}

class _PostTile extends ConsumerWidget {
  const _PostTile({required this.post, required this.orgId});

  final Post post;
  final String orgId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      title: Text(post.title),
      subtitle: Text(post.body, maxLines: 2, overflow: TextOverflow.ellipsis),
      onTap: () => _openEditor(context, orgId: orgId, existing: post),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StatusChip(status: post.status),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete',
            onPressed: () => _confirmDelete(context, ref, post),
          ),
        ],
      ),
    );
  }
}

Future<void> _confirmDelete(
  BuildContext context,
  WidgetRef ref,
  Post post,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete post?'),
      content: Text('"${post.title}" will be removed.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton.tonal(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (ok == true) {
    await ref.read(postRepositoryProvider).deleteById(post.id);
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final PostStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      PostStatus.draft => Colors.grey,
      PostStatus.published => Colors.green,
      PostStatus.archived => Colors.orange,
    };
    return Chip(
      label: Text(status.name),
      backgroundColor: color.withValues(alpha: 0.15),
      side: BorderSide(color: color),
    );
  }
}

/// Form for create + update. With `existing == null` it adds a new post
/// via `repo.add()`; otherwise it patches via `repo.updateById()`. Both
/// paths exercise generated code — `Post.toJson()` for the create,
/// the field-map for the partial update.
class PostEditorScreen extends ConsumerStatefulWidget {
  const PostEditorScreen({super.key, required this.orgId, this.existing});

  final String orgId;
  final Post? existing;

  @override
  ConsumerState<PostEditorScreen> createState() => _PostEditorScreenState();
}

class _PostEditorScreenState extends ConsumerState<PostEditorScreen> {
  late final TextEditingController _title;
  late final TextEditingController _body;
  late PostStatus _status;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _body = TextEditingController(text: e?.body ?? '');
    _status = e?.status ?? PostStatus.draft;
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  bool get _isEdit => widget.existing != null;

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(postRepositoryProvider);
      if (_isEdit) {
        await repo.updateById(widget.existing!.id, {
          'title': _title.text.trim(),
          'body': _body.text.trim(),
          'status': _status.toJson(),
        });
      } else {
        // Use Firestore's auto-id alongside the firepack-generated repo.
        // The Post model's `id` is required, so we mint one before
        // building the immutable model.
        final id = FirebaseFirestore.instance.collection('posts').doc().id;
        await repo.add(Post(
          id: id,
          organizationId: widget.orgId,
          authorId: _demoAuthorId,
          title: _title.text.trim(),
          body: _body.text.trim(),
          status: _status,
          createdAt: DateTime.now(),
          publishedAt: _status == PostStatus.published ? DateTime.now() : null,
        ));
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit post' : 'New post')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _body,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Body',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<PostStatus>(
              initialValue: _status,
              decoration: const InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
              ),
              items: PostStatus.values
                  .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                  .toList(),
              onChanged: (v) => setState(() => _status = v ?? _status),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(_isEdit ? 'Save changes' : 'Create post'),
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
