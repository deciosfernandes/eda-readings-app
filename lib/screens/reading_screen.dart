import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:showcaseview/showcaseview.dart';
import '../api/eda_client.dart';
import '../services/secure_storage_service.dart';
import '../services/history_service.dart';
import '../models/reading_models.dart';

class ReadingScreen extends StatelessWidget {
  const ReadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ReadingScreen();
  }
}

class _ReadingScreen extends StatefulWidget {
  const _ReadingScreen();

  @override
  State<_ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends State<_ReadingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _c1Controller = TextEditingController();
  final _c2Controller = TextEditingController();
  final _c3Controller = TextEditingController();
  final _f1FocusNode = FocusNode();
  final _f2FocusNode = FocusNode();
  final _f3FocusNode = FocusNode();
  final GlobalKey _input1Key = GlobalKey();
  final GlobalKey _submitButtonKey = GlobalKey();
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;
  ReadingResponse? _currentData;
  EDAClient? _client;
  String? _activeProfileId;

  // BOLT: Pre-calculated UI strings to avoid redundant tr() lookups and string
  // parsing during high-frequency input loops (setState on every keystroke).
  late String _appBarTitle;
  late String _retryButtonLabel;
  late String _submitButtonLabel;
  late String _unitLabel;
  late String _clearTooltip;
  late String _input1TutorialTitle;
  late String _input1TutorialDesc;
  late String _submitTutorialTitle;
  late String _submitTutorialDesc;
  late String _submitTooltip;

  // Pre-parsed comparison values for consumption calculation.
  double? _lastVal1;
  double? _lastVal2;
  double? _lastVal3;

  // Pre-calculated helper text bases (last reading + range).
  String _helperBase1 = '';
  String _helperBase2 = '';
  String _helperBase3 = '';

  // Pre-calculated field labels.
  String _label1 = '';
  String _label2 = '';
  String _label3 = '';

  @override
  void initState() {
    super.initState();
    ShowcaseView.register();

    // BOLT: Initialize static UI strings early so they are available even if loading fails.
    _appBarTitle = 'reading.title'.tr();
    _retryButtonLabel = 'common.retry'.tr();
    _submitButtonLabel = 'reading.submit'.tr();
    _unitLabel = 'reading.unit_kwh'.tr();
    _clearTooltip = 'common.clear'.tr();
    _input1TutorialTitle = 'tutorial.reading_input_title'.tr();
    _input1TutorialDesc = 'tutorial.reading_input_desc'.tr();
    _submitTutorialTitle = 'tutorial.reading_submit_title'.tr();
    _submitTutorialDesc = 'tutorial.reading_submit_desc'.tr();
    _submitTooltip = 'reading.submit_tooltip'.tr();

    _loadInitialData();

    _f1FocusNode.addListener(() {
      if (!_f1FocusNode.hasFocus) _formKey.currentState?.validate();
    });
    _f2FocusNode.addListener(() {
      if (!_f2FocusNode.hasFocus) _formKey.currentState?.validate();
    });
    _f3FocusNode.addListener(() {
      if (!_f3FocusNode.hasFocus) _formKey.currentState?.validate();
    });
  }

  @override
  void dispose() {
    _c1Controller.dispose();
    _c2Controller.dispose();
    _c3Controller.dispose();
    _f1FocusNode.dispose();
    _f2FocusNode.dispose();
    _f3FocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final creds = await SecureStorageService().getCredentials();
      if (creds == null) throw Exception('No credentials');

      _client = EDAClient(
        clientNumber: creds['cil']!,
        contractNumber: creds['contract']!,
      );

      final data = await _client!.getReading();
      final appState = await SecureStorageService().getAppState();

      // BOLT: Pre-calculate labels and parse numeric values once during load.
      // This eliminates redundant lookups and string parsing in the high-frequency build loop.
      _label1 = '${data.descContador1 ?? 'reading.counter_1'.tr()} *';
      _label2 = data.descContador2 ?? 'reading.counter_2'.tr();
      _label3 = data.descContador3 ?? 'reading.counter_3'.tr();

      _lastVal1 = double.tryParse((data.valorContador1 ?? '0').replaceAll(',', '.'));
      _lastVal2 = data.valorContador2 != null
          ? double.tryParse(data.valorContador2!.replaceAll(',', '.'))
          : null;
      _lastVal3 = data.valorContador3 != null
          ? double.tryParse(data.valorContador3!.replaceAll(',', '.'))
          : null;

      _helperBase1 = _buildHelperBase(
        data.valorContador1,
        data.valorMinContador1,
        data.valorMaxContador1,
      );
      _helperBase2 = _buildHelperBase(
        data.valorContador2,
        data.valorMinContador2,
        data.valorMaxContador2,
      );
      _helperBase3 = _buildHelperBase(
        data.valorContador3,
        data.valorMinContador3,
        data.valorMaxContador3,
      );

      setState(() {
        _currentData = data;
        _activeProfileId = appState.profiles.isNotEmpty
            ? appState.profiles[appState.activeProfileIndex].id
            : null;
        _isLoading = false;
      });

      _startTutorial();
    } catch (e, stack) {
      debugPrint('Error loading reading data: $e');
      debugPrint('Stack trace: $stack');
      setState(() {
        _error = 'reading.error_load'.tr();
        _isLoading = false;
      });
    }
  }

  void _startTutorial() async {
    final storage = SecureStorageService();
    final hasSeen = await storage.hasSeenReadingTutorial();
    if (!hasSeen && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ShowcaseView.get().startShowCase([_input1Key, _submitButtonKey]);
        storage.setSeenReadingTutorial(true);
      });
    }
  }

  Future<void> _submitReading() async {
    if (!_formKey.currentState!.validate()) return;
    if (_currentData == null || _client == null) return;

    final confirmed = await _showConfirmDialog();
    if (!confirmed) return;

    HapticFeedback.mediumImpact();
    setState(() => _isSubmitting = true);

    try {
      // Re-fetch if token expired
      if (DateTime.fromMillisecondsSinceEpoch(_currentData!.cilTokenExpires)
          .isBefore(DateTime.now())) {
        final refreshed = await _client!.getReading();
        if (!mounted) return;
        setState(() => _currentData = refreshed);
      }

      final payload = SendReadingPayload(
        cil: _currentData!.cil,
        cilToken: _currentData!.cilToken,
        cilTokenExpires: _currentData!.cilTokenExpires,
        serial: _currentData!.serial,
        material: _currentData!.material,
        valorContador1: _c1Controller.text.trim(),
        register1: _currentData!.register1 ?? '',
        valorContador2: _c2Controller.text.isEmpty ? null : _c2Controller.text.trim(),
        register2: _currentData!.register2,
        valorContador3: _c3Controller.text.isEmpty ? null : _c3Controller.text.trim(),
        register3: _currentData!.register3,
      );

      // Send to API
      await _client!.sendReading(payload);

      // Save locally
      await HistoryService().addReading(LocalReadingHistory(
        date: DateTime.now(),
        valorContador1: _c1Controller.text.trim(),
        valorContador2: _c2Controller.text.trim().isEmpty ? null : _c2Controller.text.trim(),
        valorContador3: _c3Controller.text.trim().isEmpty ? null : _c3Controller.text.trim(),
        profileId: _activeProfileId,
      ));

      if (!mounted) return;
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text('reading.success'.tr())),
            ],
          ),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop(true); // Return true to indicate success to Dashboard
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('reading.error_send'.tr()),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isSubmitting = false);
    }
  }

  String? _validateReading(String? value, String? min, String? max) {
    if (value == null || value.isEmpty) {
      return 'login.error_empty'.tr();
    }
    final number = double.tryParse(value.replaceAll(',', '.'));

    // Sentinel: Security check for finite numbers and non-negative values.
    // double.tryParse accepts "NaN" and "Infinity" literals which could bypass logic.
    if (number == null || !number.isFinite || number < 0) {
      return 'reading.error_not_number'.tr();
    }

    if (min != null && max != null) {
      final minVal = double.tryParse(min.replaceAll(',', '.'));
      final maxVal = double.tryParse(max.replaceAll(',', '.'));
      if (minVal != null && maxVal != null) {
        if (number < minVal || number > maxVal) {
          return 'reading.error_out_of_bounds'.tr(args: [min, max]);
        }
      }
    }
    return null;
  }

  Future<bool> _showConfirmDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('reading.confirm_title'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('reading.confirm_message'.tr()),
            const SizedBox(height: 16),
            _buildConfirmRow(_currentData!.descContador1 ?? 'reading.counter_1'.tr(), _c1Controller.text),
            if (_c2Controller.text.isNotEmpty)
              _buildConfirmRow(_currentData!.descContador2 ?? 'reading.counter_2'.tr(), _c2Controller.text),
            if (_c3Controller.text.isNotEmpty)
              _buildConfirmRow(_currentData!.descContador3 ?? 'reading.counter_3'.tr(), _c3Controller.text),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('common.cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('reading.confirm_send'.tr()),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Widget _buildConfirmRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold)),
          Text('$value $_unitLabel'),
        ],
      ),
    );
  }

  String _buildHelperBase(String? lastValue, String? minValue, String? maxValue) {
    final lastReadingText = 'reading.last_reading'.tr(args: [lastValue ?? '0']);
    final rangeText = (minValue != null && maxValue != null)
        ? ' • ${'reading.min_max_helper'.tr(args: [minValue, maxValue])}'
        : '';
    return '$lastReadingText$rangeText';
  }

  InputDecoration _buildInputDecoration({
    required String label,
    required double? lastValue,
    required String helperBase,
    required TextEditingController controller,
  }) {
    String consumptionText = '';
    if (lastValue != null && controller.text.isNotEmpty) {
      final current = double.tryParse(controller.text.replaceAll(',', '.'));
      if (current != null && current > lastValue) {
        final diff = current - lastValue;
        consumptionText =
            ' (+${diff.toStringAsFixed(diff.truncateToDouble() == diff ? 0 : 2)})';
      }
    }

    return InputDecoration(
      labelText: label,
      suffixIcon: controller.text.isNotEmpty
          ? IconButton(
              icon: const Icon(Icons.clear),
              tooltip: _clearTooltip,
              onPressed: () {
                HapticFeedback.selectionClick();
                controller.clear();
                setState(() {});
              },
            )
          : null,
      suffixText: _unitLabel,
      helperText: '$helperBase$consumptionText',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(_appBarTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // BOLT: Hoist Theme and ColorScheme lookups to avoid redundant InheritedWidget traversals.
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(_appBarTitle)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: colorScheme.primary.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: textTheme.titleLarge,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _error = null;
                      _isLoading = true;
                    });
                    _loadInitialData();
                  },
                  icon: const Icon(Icons.refresh),
                  label: Text(_retryButtonLabel),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(_appBarTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Showcase(
                key: _input1Key,
                title: _input1TutorialTitle,
                description: _input1TutorialDesc,
                child: TextFormField(
                  controller: _c1Controller,
                  focusNode: _f1FocusNode,
                  enabled: !_isSubmitting,
                  maxLength: 15,
                  autofocus: true,
                  textInputAction: (_currentData!.descContador2 != null &&
                          _currentData!.descContador2!.isNotEmpty)
                      ? TextInputAction.next
                      : TextInputAction.done,
                  onFieldSubmitted: (_) {
                    if (_currentData!.descContador2 != null &&
                        _currentData!.descContador2!.isNotEmpty) {
                      FocusScope.of(context).requestFocus(_f2FocusNode);
                    } else {
                      _submitReading();
                    }
                  },
                  onChanged: (_) => setState(() {}),
                  decoration: _buildInputDecoration(
                    label: _label1,
                    lastValue: _lastVal1,
                    helperBase: _helperBase1,
                    controller: _c1Controller,
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) => _validateReading(
                    value,
                    _currentData!.valorMinContador1,
                    _currentData!.valorMaxContador1,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_currentData!.descContador2 != null &&
                  _currentData!.descContador2!.isNotEmpty) ...[
                TextFormField(
                  controller: _c2Controller,
                  focusNode: _f2FocusNode,
                  enabled: !_isSubmitting,
                  maxLength: 15,
                  textInputAction: (_currentData!.descContador3 != null &&
                          _currentData!.descContador3!.isNotEmpty)
                      ? TextInputAction.next
                      : TextInputAction.done,
                  onFieldSubmitted: (_) {
                    if (_currentData!.descContador3 != null &&
                        _currentData!.descContador3!.isNotEmpty) {
                      FocusScope.of(context).requestFocus(_f3FocusNode);
                    } else {
                      _submitReading();
                    }
                  },
                  onChanged: (_) => setState(() {}),
                  decoration: _buildInputDecoration(
                    label: _label2,
                    lastValue: _lastVal2,
                    helperBase: _helperBase2,
                    controller: _c2Controller,
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) return null; // Optional
                    return _validateReading(
                      value,
                      _currentData!.valorMinContador2,
                      _currentData!.valorMaxContador2,
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],
              if (_currentData!.descContador3 != null &&
                  _currentData!.descContador3!.isNotEmpty) ...[
                TextFormField(
                  controller: _c3Controller,
                  focusNode: _f3FocusNode,
                  enabled: !_isSubmitting,
                  maxLength: 15,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submitReading(),
                  onChanged: (_) => setState(() {}),
                  decoration: _buildInputDecoration(
                    label: _label3,
                    lastValue: _lastVal3,
                    helperBase: _helperBase3,
                    controller: _c3Controller,
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) return null; // Optional
                    return _validateReading(
                      value,
                      _currentData!.valorMinContador3,
                      _currentData!.valorMaxContador3,
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: Tooltip(
                  message: _submitTooltip,
                  child: Showcase(
                    key: _submitButtonKey,
                    title: _submitTutorialTitle,
                    description: _submitTutorialDesc,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitReading,
                      child: _isSubmitting
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colorScheme.onPrimary,
                              ),
                            )
                          : Text(_submitButtonLabel),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
