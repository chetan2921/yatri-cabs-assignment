import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../utils/app_theme.dart';
import '../utils/cities.dart';

class CitySearchField extends StatefulWidget {
  final String label;
  final String hint;
  final String value;
  final Widget leadingIcon;
  final Widget trailingIcon;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final List<String> suggestions;
  final bool usePhotonSuggestions;

  const CitySearchField({
    super.key,
    required this.label,
    required this.hint,
    required this.value,
    required this.leadingIcon,
    required this.trailingIcon,
    required this.onChanged,
    required this.onClear,
    this.suggestions = indianCities,
    this.usePhotonSuggestions = true,
  });

  @override
  State<CitySearchField> createState() => _CitySearchFieldState();
}

class _CitySearchFieldState extends State<CitySearchField> {
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  List<String> _filteredSuggestions = [];
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  Timer? _searchDebounce;
  int _activeRequestId = 0;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        _hideDropdown();
      }
    });
  }

  @override
  void didUpdateWidget(CitySearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  void _onTextChanged(String text) {
    widget.onChanged(text);
    _searchDebounce?.cancel();

    if (text.isEmpty) {
      _hideDropdown();
      return;
    }

    if (!widget.usePhotonSuggestions) {
      _applyLocalSuggestions(text);
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 320), () {
      _fetchPhotonSuggestions(text);
    });
  }

  void _applyLocalSuggestions(String text) {
    final filtered = widget.suggestions
        .where((c) => c.toLowerCase().startsWith(text.toLowerCase()))
        .take(6)
        .toList();
    _applySuggestions(filtered);
  }

  void _applySuggestions(List<String> suggestions) {
    if (!mounted) return;
    setState(() {
      _filteredSuggestions = suggestions;
    });
    if (suggestions.isNotEmpty) {
      _showOverlay();
    } else {
      _hideDropdown();
    }
  }

  Future<void> _fetchPhotonSuggestions(String text) async {
    final query = text.trim();
    if (query.length < 2) {
      _applyLocalSuggestions(text);
      return;
    }

    final requestId = ++_activeRequestId;

    try {
      final uri = Uri.https('photon.komoot.io', '/api/', {
        'q': query,
        'limit': '6',
        'lang': 'en',
        'osm_tag': 'place:city',
        // India bounding box: west,south,east,north
        'bbox': '68,6,98,37',
      });

      final response = await http.get(uri).timeout(const Duration(seconds: 6));

      if (!mounted || requestId != _activeRequestId) return;

      if (response.statusCode != 200) {
        _applyLocalSuggestions(text);
        return;
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final features = body['features'] as List<dynamic>? ?? const [];

      final Set<String> names = <String>{};
      for (final item in features) {
        final feature = item as Map<String, dynamic>?;
        final props = feature?['properties'] as Map<String, dynamic>?;
        final name = (props?['name'] as String?)?.trim();
        final city = (props?['city'] as String?)?.trim();
        final state = (props?['state'] as String?)?.trim();

        final value = (name?.isNotEmpty == true)
            ? name!
            : (city?.isNotEmpty == true)
            ? city!
            : (state?.isNotEmpty == true)
            ? state!
            : '';

        if (value.isNotEmpty) {
          names.add(value);
        }
      }

      final photonSuggestions = names.take(6).toList();
      if (photonSuggestions.isEmpty) {
        _applyLocalSuggestions(text);
        return;
      }

      _applySuggestions(photonSuggestions);
    } catch (_) {
      if (!mounted || requestId != _activeRequestId) return;
      _applyLocalSuggestions(text);
    }
  }

  void _showOverlay() {
    _hideDropdown();
    _overlayEntry = _buildOverlay();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideDropdown() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _buildOverlay() {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    return OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 2),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _filteredSuggestions.map((city) {
                  return InkWell(
                    onTap: () {
                      _controller.text = city;
                      widget.onChanged(city);
                      _hideDropdown();
                      _focusNode.unfocus();
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.grey.shade100,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              city,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _hideDropdown();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Container(
        height: 58,
        decoration: BoxDecoration(
          color: AppColors.fieldBg,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 4,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            widget.leadingIcon,
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(widget.label, style: AppTextStyles.fieldLabel),
                  TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    onChanged: _onTextChanged,
                    style: GoogleFonts.poppins(
                      color: Colors.black87,
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      hintText: widget.hint,
                      hintStyle: AppTextStyles.fieldHint,
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () {
                _controller.clear();
                widget.onClear();
                _hideDropdown();
              },
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: widget.trailingIcon,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
