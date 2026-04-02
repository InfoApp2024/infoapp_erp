import 'package:flutter/material.dart';
import 'package:infoapp/core/branding/branding_colors.dart';
import 'package:flutter/services.dart';

class InventorySearchBar extends StatefulWidget {
  final String? initialValue;
  final String hintText;
  final Function(String) onChanged;
  final Function(String)? onSubmitted;
  final Function()? onClear;
  final bool showFilters;
  final Function()? onFiltersPressed;
  final bool isLoading;
  final List<String>? suggestions;
  final Function(String)? onSuggestionSelected;
  final bool enabled;
  final IconData? prefixIcon;
  final String? helpText;

  const InventorySearchBar({
    super.key,
    this.initialValue,
    this.hintText = 'Buscar productos...',
    required this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.showFilters = true,
    this.onFiltersPressed,
    this.isLoading = false,
    this.suggestions,
    this.onSuggestionSelected,
    this.enabled = true,
    this.prefixIcon,
    this.helpText,
  });

  @override
  State<InventorySearchBar> createState() => _InventorySearchBarState();
}

class _InventorySearchBarState extends State<InventorySearchBar>
    with SingleTickerProviderStateMixin {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  bool _showSuggestions = false;
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue ?? '');
    _focusNode = FocusNode();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _focusNode.addListener(_onFocusChange);
    _animationController.forward();
  }

  @override
  void dispose() {
    _removeOverlay();
    _controller.dispose();
    _focusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      _showSuggestionsIfNeeded();
    } else {
      _hideSuggestions();
    }
  }

  void _showSuggestionsIfNeeded() {
    if (widget.suggestions != null &&
        widget.suggestions!.isNotEmpty &&
        _controller.text.isNotEmpty) {
      _showSuggestions = true;
      _showOverlay();
    }
  }

  void _hideSuggestions() {
    _showSuggestions = false;
    _removeOverlay();
  }

  void _showOverlay() {
    _removeOverlay();
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(
      builder:
          (context) => Positioned(
            width: context.size?.width,
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: const Offset(0, 60),
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300, width: 1),
                  ),
                  child: _buildSuggestionsList(),
                ),
              ),
            ),
          ),
    );
  }

  Widget _buildSuggestionsList() {
    final filteredSuggestions =
        widget.suggestions!
            .where(
              (suggestion) => suggestion.toLowerCase().contains(
                _controller.text.toLowerCase(),
              ),
            )
            .take(5)
            .toList();

    if (filteredSuggestions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'No se encontraron sugerencias',
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: filteredSuggestions.length,
      itemBuilder: (context, index) {
        final suggestion = filteredSuggestions[index];
        return ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          leading: Icon(Icons.search, color: Colors.grey.shade400, size: 20),
          title: Text(suggestion, style: const TextStyle(fontSize: 14)),
          onTap: () {
            _controller.text = suggestion;
            widget.onSuggestionSelected?.call(suggestion);
            _hideSuggestions();
            _focusNode.unfocus();
          },
        );
      },
    );
  }

  void _onTextChanged(String value) {
    widget.onChanged(value);

    if (value.isNotEmpty && widget.suggestions != null) {
      _showSuggestionsIfNeeded();
    } else {
      _hideSuggestions();
    }
  }

  void _clearSearch() {
    _controller.clear();
    widget.onChanged('');
    widget.onClear?.call();
    _hideSuggestions();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: CompositedTransformTarget(
            link: _layerLink,
            child: _buildSearchBar(),
          ),
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            focusNode: _focusNode,
            enabled: widget.enabled,
            style: const TextStyle(fontSize: 16, color: Colors.black87),
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 16),
              prefixIcon:
                  widget.isLoading
                      ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.blue,
                            ),
                          ),
                        ),
                      )
                      : Icon(
                        widget.prefixIcon ?? Icons.search,
                        color: Colors.grey.shade400,
                        size: 24,
                      ),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_controller.text.isNotEmpty)
                    IconButton(
                      icon: Icon(
                        Icons.clear,
                        color: Colors.grey.shade400,
                        size: 20,
                      ),
                      onPressed: _clearSearch,
                      tooltip: 'Limpiar búsqueda',
                    ),
                  if (widget.showFilters)
                    IconButton(
                      icon: Icon(
                        Icons.tune,
                        color: Colors.grey.shade600,
                        size: 22,
                      ),
                      onPressed: widget.onFiltersPressed,
                      tooltip: 'Filtros avanzados',
                    ),
                ],
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.blue, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: _onTextChanged,
            onSubmitted: widget.onSubmitted,
            textInputAction: TextInputAction.search,
            inputFormatters: [LengthLimitingTextInputFormatter(100)],
          ),
          if (widget.helpText != null)
            Padding(
              padding: const EdgeInsets.only(
                left: 16,
                right: 16,
                top: 8,
                bottom: 4,
              ),
              child: Text(
                widget.helpText!,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ),
        ],
      ),
    );
  }
}

// Widget de búsqueda rápida para SKU
class InventorySkuSearchBar extends StatefulWidget {
  final Function(String) onSkuChanged;
  final Function(String)? onSkuSubmitted;
  final bool isValidating;
  final String? validationMessage;
  final bool isValid;
  final String? initialSku;

  const InventorySkuSearchBar({
    super.key,
    required this.onSkuChanged,
    this.onSkuSubmitted,
    this.isValidating = false,
    this.validationMessage,
    this.isValid = true,
    this.initialSku,
  });

  @override
  State<InventorySkuSearchBar> createState() => _InventorySkuSearchBarState();
}

class _InventorySkuSearchBarState extends State<InventorySkuSearchBar> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialSku ?? '');
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Color _getBorderColor(BuildContext context) {
    if (widget.isValidating) return context.warningColor;
    if (widget.validationMessage != null && !widget.isValid) return context.errorColor;
    if (widget.isValid && _controller.text.isNotEmpty) return context.successColor;
    return Theme.of(context).colorScheme.outlineVariant;
  }

  IconData _getSuffixIcon() {
    if (widget.isValidating) return Icons.hourglass_empty;
    if (widget.validationMessage != null && !widget.isValid) {
      return Icons.error_outline;
    }
    if (widget.isValid && _controller.text.isNotEmpty) {
      return Icons.check_circle_outline;
    }
    return Icons.qr_code_scanner;
  }

  Color _getSuffixIconColor(BuildContext context) {
    if (widget.isValidating) return context.warningColor;
    if (widget.validationMessage != null && !widget.isValid) return context.errorColor;
    if (widget.isValid && _controller.text.isNotEmpty) return context.successColor;
    return Theme.of(context).hintColor;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
          decoration: InputDecoration(
            labelText: 'SKU del Producto',
            hintText: 'Ej: PROD-2024-001',
            prefixIcon: Icon(Icons.inventory, color: Colors.grey.shade400),
            suffixIcon:
                widget.isValidating
                    ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          // El color se toma del tema de advertencia
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.transparent),
                        ),
                      ),
                    )
                    : Icon(_getSuffixIcon(), color: _getSuffixIconColor(context)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _getBorderColor(context), width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _getBorderColor(context), width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _getBorderColor(context), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          onChanged: widget.onSkuChanged,
          onSubmitted: widget.onSkuSubmitted,
          textInputAction: TextInputAction.search,
          inputFormatters: [
            LengthLimitingTextInputFormatter(50),
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\-_]')),
          ],
        ),
        if (widget.validationMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 16),
            child: Row(
              children: [
                Icon(
                  widget.isValid ? Icons.check_circle : Icons.error,
                  size: 16,
                  color: widget.isValid ? context.successColor : context.errorColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.validationMessage!,
                    style: TextStyle(
                      fontSize: 12,
                      color: widget.isValid ? context.successColor : context.errorColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
