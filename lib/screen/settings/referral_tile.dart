import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ReferralTile extends StatelessWidget {
  final String photoUrl;
  final String name;
  final String date;

  const ReferralTile({
    super.key,
    required this.photoUrl,
    required this.name,
    required this.date,
  });

  bool get _isPhotoAvailable =>
      photoUrl.isNotEmpty && !photoUrl.contains('placeholder');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: theme.dividerColor.withOpacity(0.5),
                      width: 2,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(
                    child: _isPhotoAvailable
                        ? Image.network(
                            photoUrl,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildDefaultAvatar(theme, context);
                            },
                          )
                        : _buildDefaultAvatar(theme, context),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  name,
                  style: GoogleFonts.outfit(
                    color: theme.textTheme.bodyLarge?.color ??
                        const Color(0xFF212121),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            Text(
              date,
              style: GoogleFonts.outfit(
                color:
                    theme.textTheme.bodySmall?.color ?? const Color(0xFF999999),
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar(ThemeData theme, BuildContext context) {
    final bool isLight = theme.brightness == Brightness.light;
    return Container(
      child: Center(
        child: Icon(
          Icons.person,
          color: isLight ? Colors.black : Colors.white,
        ),
      ),
    );
  }
}
