// lib/views/home/widgets/route_photos_section.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '/models/route_photo_model.dart';
import '/controllers/route_photos_controller.dart';

class RoutePhotosSection extends StatelessWidget {
  final Future<List<RoutePhoto>> photosFuture;
  final RoutePhotosController photosCtrl;
  final bool uploading;
  final String? currentUserId;
  final VoidCallback onAddPhoto;
  final void Function(String url) onViewPhoto;
  final void Function(RoutePhoto photo) onDeletePhoto;

  const RoutePhotosSection({
    super.key,
    required this.photosFuture,
    required this.photosCtrl,
    required this.uploading,
    required this.currentUserId,
    required this.onAddPhoto,
    required this.onViewPhoto,
    required this.onDeletePhoto,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Photos from Runners',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        FutureBuilder<List<RoutePhoto>>(
          future: photosFuture,
          builder: (context, snap) {
            final items = snap.data ?? const <RoutePhoto>[];

            if (snap.connectionState == ConnectionState.waiting &&
                items.isEmpty) {
              return const SizedBox(
                height: 86,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final count = 1 + items.length;

            return SizedBox(
              height: 86,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: count,
                separatorBuilder: (context, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _AddPhotoTile(onTap: uploading ? null : onAddPhoto);
                  }

                  final photo = items[index - 1];
                  final displayUrl =
                      photo.url ?? photosCtrl.getPublicUrl(photo.storagePath);
                  final isOwner = currentUserId == photo.userId;

                  return _PhotoThumb.network(
                    displayUrl,
                    onTap: () => onViewPhoto(displayUrl),
                    onLongPress: isOwner ? () => onDeletePhoto(photo) : null,
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  final VoidCallback? onTap;
  const _AddPhotoTile({this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 86,
        height: 86,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.purple, width: 1.2),
        ),
        child: const Center(
          child: Icon(Icons.add, color: Colors.purple, size: 28),
        ),
      ),
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _PhotoThumb._(this.child, {this.onTap, this.onLongPress});

  factory _PhotoThumb.network(
    String url, {
    VoidCallback? onTap,
    VoidCallback? onLongPress,
  }) {
    return _PhotoThumb._(
      ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: CachedNetworkImage(
          imageUrl: url,
          width: 86,
          height: 86,
          fit: BoxFit.cover,
          placeholder: (context, url) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          errorWidget: (context, url, error) =>
              _gradientBox(const [Color(0xFFD1C4E9), Color(0xFFB39DDB)]),
        ),
      ),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }

  static Widget _gradientBox(List<Color> colors) {
    return Container(
      width: 86,
      height: 86,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: const Icon(Icons.image, color: Colors.white, size: 28),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (onTap == null && onLongPress == null) return child;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      onLongPress: onLongPress,
      child: child,
    );
  }
}
