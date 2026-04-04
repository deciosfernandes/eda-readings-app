import 'package:flutter/material.dart';
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
  String? _error;
  ReadingResponse? _currentData;
  EDAClient? _client;

  @override
  void initState() {
    super.initState();
    ShowcaseView.register();
    _loadInitialData();
    
    // Add logic for validation on blur
    _f1FocusNode.addListener(_onFocusChange);
    _f2FocusNode.addListener(_onFocusChange);
    _f3FocusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (!_f1FocusNode.hasFocus || !_f2FocusNode.hasFocus || !_f3FocusNode.hasFocus) {
       _formKey.currentState?.validate();
    }
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
      setState(() {
        _currentData = data;
        _isLoading = false;
      });
      
      _startTutorial();
    } catch (e) {
      setState(() {
        _error = e.toString();
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

    setState(() => _isLoading = true);

    try {
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
        valorContador2: _c2Controller.text.trim(),
        valorContador3: _c3Controller.text.trim(),
      ));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('reading.success'.tr()),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop(true); // Return true to indicate success to Dashboard
      
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('reading.error_send'.tr()),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isLoading = false);
    }
  }

  String? _validateReading(String? value, String? min, String? max) {
    if (value == null || value.isEmpty) {
      return 'login.error_empty'.tr();
    }
    final number = double.tryParse(value.replaceAll(',', '.'));
    if (number == null) {
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
          Text(value),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('reading.title'.tr())),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _error != null 
          ? Center(child: Text(_error!))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Showcase(
                      key: _input1Key,
                      title: 'tutorial.reading_input_title'.tr(),
                      description: 'tutorial.reading_input_desc'.tr(),
                      child: TextFormField(
                        controller: _c1Controller,
                        focusNode: _f1FocusNode,
                        decoration: InputDecoration(
                          labelText: _currentData!.descContador1 ?? 'reading.counter_1'.tr(),
                          helperText: 'reading.last_reading'.tr(args: [
                            _currentData!.valorContador1 ?? '0'
                          ]),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) => _validateReading(
                          value, 
                          _currentData!.valorMinContador1, 
                          _currentData!.valorMaxContador1
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_currentData!.descContador2 != null && _currentData!.descContador2!.isNotEmpty) ...[
                      TextFormField(
                        controller: _c2Controller,
                        focusNode: _f2FocusNode,
                        decoration: InputDecoration(
                          labelText: _currentData!.descContador2 ?? 'reading.counter_2'.tr(),
                          helperText: 'reading.last_reading'.tr(args: [
                            _currentData!.valorContador2 ?? '0'
                          ]),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) return null; // Optional
                          return _validateReading(
                            value, 
                            _currentData!.valorMinContador2, 
                            _currentData!.valorMaxContador2
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (_currentData!.descContador3 != null && _currentData!.descContador3!.isNotEmpty) ...[
                      TextFormField(
                        controller: _c3Controller,
                        focusNode: _f3FocusNode,
                        decoration: InputDecoration(
                          labelText: _currentData!.descContador3 ?? 'reading.counter_3'.tr(),
                          helperText: 'reading.last_reading'.tr(args: [
                            _currentData!.valorContador3 ?? '0'
                          ]),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) return null; // Optional
                          return _validateReading(
                            value, 
                            _currentData!.valorMinContador3, 
                            _currentData!.valorMaxContador3
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: Showcase(
                        key: _submitButtonKey,
                        title: 'tutorial.reading_submit_title'.tr(),
                        description: 'tutorial.reading_submit_desc'.tr(),
                        child: ElevatedButton(
                          onPressed: _submitReading,
                          child: Tooltip(
                            message: 'reading.submit_tooltip'.tr(),
                            child: Text('reading.submit'.tr()),
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
