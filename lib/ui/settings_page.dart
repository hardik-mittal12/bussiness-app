import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../data/database.dart';
import '../core/backup_service.dart';
import '../core/database_diagnostic_service.dart';
import '../core/business_profile_service.dart';
import '../core/accounting_engine.dart';
import '../core/security_pin_service.dart';
import 'theme/app_theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  
  String _companyName = 'My Business Enterprise';
  String _address = '';
  String _phone = '';
  String _email = '';
  String _taxNumber = '';
  String _bankDetails = '';
  String _termsAndConditions = '';
  String? _logoPath;
  
  bool _hasSecurityPin = false;
  bool _isLoading = false;
  SystemHealthInfo? _healthInfo;
  DatabaseInvariantReport? _diagnosticReport;
  bool _isDiagnosticRunning = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadSettings();
    _loadHealthInfo();
  }

  Future<void> _loadSettings() async {
    final db = Provider.of<AppDatabase>(context, listen: false);
    final profileService = BusinessProfileService(db);
    final profile = await profileService.getProfile();
    final pinService = SecurityPinService(db);
    final hasPin = await pinService.hasPin();

    setState(() {
      _companyName = profile.companyName;
      _address = profile.address ?? '';
      _phone = profile.phone ?? '';
      _email = profile.email ?? '';
      _taxNumber = profile.taxNumber ?? '';
      _bankDetails = profile.bankDetails ?? '';
      _termsAndConditions = profile.termsAndConditions ?? '';
      _logoPath = profile.logoPath;
      _hasSecurityPin = hasPin;
    });
  }

  Future<void> _loadHealthInfo() async {
    try {
      final diagService = Provider.of<DatabaseDiagnosticService>(context, listen: false);
      final info = await diagService.getSystemHealthInfo();
      setState(() {
        _healthInfo = info;
      });
    } catch (e) {
      // Ignored
    }
  }

  Future<void> _pickLogo() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
      );

      if (result.isNotEmpty && result.first.path != null) {
        final path = result.first.path!;
        if (!mounted) return;
        final db = Provider.of<AppDatabase>(context, listen: false);
        final profileService = BusinessProfileService(db);
        await profileService.updateLogo(path);
        await _loadSettings();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(backgroundColor: AppColors.success, content: Text('Company logo updated successfully.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.error, content: Text('Failed to select logo: $e')),
        );
      }
    }
  }

  Future<void> _removeLogo() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Remove Logo', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to remove the company logo?', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)), onPressed: () => Navigator.pop(ctx, false)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (!mounted) return;
      final db = Provider.of<AppDatabase>(context, listen: false);
      final profileService = BusinessProfileService(db);
      await profileService.updateLogo(null);
      await _loadSettings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Company logo removed.')),
        );
      }
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final db = Provider.of<AppDatabase>(context, listen: false);
    setState(() => _isLoading = true);

    try {
      final profileService = BusinessProfileService(db);
      await profileService.updateProfile(
        companyName: _companyName,
        address: _address.isNotEmpty ? _address : null,
        phone: _phone.isNotEmpty ? _phone : null,
        email: _email.isNotEmpty ? _email : null,
        taxNumber: _taxNumber.isNotEmpty ? _taxNumber : null,
        bankDetails: _bankDetails.isNotEmpty ? _bankDetails : null,
        termsAndConditions: _termsAndConditions.isNotEmpty ? _termsAndConditions : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: AppColors.success, content: Text('Company details saved successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.error, content: Text('Failed to save settings: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _promptDataReset() async {
    final textController = TextEditingController();
    bool keepMasters = true;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 28),
                SizedBox(width: 8),
                Text('Reset Business Data', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'DANGER: This action wipes all transactions, invoices, payments, receipts, and ledger balances.',
                    style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Company Profile settings and Company Logo will be completely preserved.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    value: keepMasters,
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppColors.primary,
                    title: const Text('Preserve Master Accounts (Customers, Suppliers, Stock Items)', style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: const Text('If checked, only transactions are wiped. If unchecked, custom ledger & stock items are also cleared.', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                    onChanged: (val) => setModalState(() => keepMasters = val ?? true),
                  ),
                  const SizedBox(height: 16),
                  const Text('Type "RESET" below to confirm:', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: textController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Type RESET',
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
                onPressed: () => Navigator.pop(ctx, false),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                child: const Text('Proceed with Data Reset', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: () {
                  if (textController.text.trim() == 'RESET') {
                    Navigator.pop(ctx, true);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(backgroundColor: AppColors.error, content: Text('Please type RESET exactly to confirm.')),
                    );
                  }
                },
              ),
            ],
          );
        },
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      final engine = Provider.of<AccountingEngine>(context, listen: false);
      await engine.resetBusinessData(keepMasters: keepMasters);
      await _loadHealthInfo();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: AppColors.success, content: Text('Business transaction data has been completely reset.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.error, content: Text('Reset failed: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _runIntegrityCheck() async {
    setState(() => _isDiagnosticRunning = true);
    try {
      final diagService = Provider.of<DatabaseDiagnosticService>(context, listen: false);
      final report = await diagService.runInvariantCheck();
      setState(() => _diagnosticReport = report);
      await _loadHealthInfo();

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: Row(
              children: [
                Icon(
                  report.isHealthy ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                  color: report.isHealthy ? AppColors.success : AppColors.error,
                ),
                const SizedBox(width: 8),
                Text(
                  report.isHealthy ? 'Database Healthy' : 'Integrity Issues Detected',
                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Audit Checklist Results:', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    ...report.passedChecks.map((p) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: Row(
                        children: [
                          const Icon(Icons.check_rounded, color: AppColors.success, size: 16),
                          const SizedBox(width: 6),
                          Expanded(child: Text(p, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))),
                        ],
                      ),
                    )),
                    if (report.failedChecks.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text('Failed Invariant Checks:', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                      ...report.failedChecks.map((f) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: Row(
                          children: [
                            const Icon(Icons.close_rounded, color: AppColors.error, size: 16),
                            const SizedBox(width: 6),
                            Expanded(child: Text(f, style: const TextStyle(color: AppColors.error, fontSize: 12))),
                          ],
                        ),
                      )),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                child: const Text('Close', style: TextStyle(color: AppColors.textPrimary)),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.error, content: Text('Integrity check error: $e')),
        );
      }
    } finally {
      setState(() => _isDiagnosticRunning = false);
    }
  }

  Future<void> _triggerBackup() async {
    setState(() => _isLoading = true);
    try {
      final backupService = Provider.of<BackupService>(context, listen: false);
      final metadata = await backupService.createBackup(label: 'manual');
      await _loadHealthInfo();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.success, content: Text('Backup created & verified: ${metadata.fileName}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.error, content: Text('Backup failed: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyLastBackup() async {
    if (_healthInfo?.lastBackup == null) return;
    setState(() => _isLoading = true);
    try {
      final backupService = Provider.of<BackupService>(context, listen: false);
      final res = await backupService.verifyBackup(_healthInfo!.lastBackup!.filePath);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: res.isSuccess ? AppColors.success : AppColors.error,
            content: Text(res.isSuccess ? 'Backup Verified: ${res.message}' : 'Verification Failed: ${res.message}'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.error, content: Text('Verify error: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _promptChangePin() async {
    final currentPinController = TextEditingController();
    final newPinController = TextEditingController();
    final confirmPinController = TextEditingController();
    String dialogError = '';
    bool isSaving = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Row(
              children: [
                const Icon(Icons.password_rounded, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  _hasSecurityPin ? 'Change Access PIN' : 'Set Up Access PIN',
                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _hasSecurityPin
                          ? 'Enter your current 4-digit PIN, then enter and confirm your new passcode.'
                          : 'Enter and confirm a 4-digit passcode to lock the application on startup.',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    if (_hasSecurityPin) ...[
                      TextField(
                        controller: currentPinController,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: 'Current 4-Digit PIN',
                          counterText: '',
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: newPinController,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      autofocus: !_hasSecurityPin,
                      decoration: const InputDecoration(
                        labelText: 'New 4-Digit PIN',
                        counterText: '',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmPinController,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      decoration: const InputDecoration(
                        labelText: 'Confirm New 4-Digit PIN',
                        counterText: '',
                        isDense: true,
                      ),
                    ),
                    if (dialogError.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.errorBg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                dialogError,
                                style: const TextStyle(color: AppColors.error, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onPressed: isSaving
                    ? null
                    : () async {
                        final currentPin = currentPinController.text.trim();
                        final newPin = newPinController.text.trim();
                        final confirmPin = confirmPinController.text.trim();

                        if (_hasSecurityPin && (currentPin.length != 4 || int.tryParse(currentPin) == null)) {
                          setDialogState(() => dialogError = 'Please enter your current 4-digit PIN.');
                          return;
                        }
                        if (newPin.length != 4 || int.tryParse(newPin) == null) {
                          setDialogState(() => dialogError = 'New PIN must be exactly 4 digits.');
                          return;
                        }
                        if (newPin != confirmPin) {
                          setDialogState(() => dialogError = 'New PINs do not match. Please re-enter.');
                          return;
                        }

                        setDialogState(() {
                          isSaving = true;
                          dialogError = '';
                        });

                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          final db = Provider.of<AppDatabase>(context, listen: false);
                          final pinService = SecurityPinService(db);

                          if (_hasSecurityPin) {
                            final isValid = await pinService.verifyPin(currentPin);
                            if (!isValid) {
                              setDialogState(() {
                                isSaving = false;
                                dialogError = 'Current PIN is incorrect.';
                              });
                              return;
                            }
                          }

                          await pinService.setPin(newPin);
                          if (dialogCtx.mounted) Navigator.pop(dialogCtx);

                          setState(() => _hasSecurityPin = true);
                          if (mounted) {
                            messenger.showSnackBar(
                              const SnackBar(
                                backgroundColor: AppColors.success,
                                content: Text('Security PIN updated successfully.'),
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() {
                            isSaving = false;
                            dialogError = 'Failed to update PIN: $e';
                          });
                        }
                      },
                child: isSaving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(_hasSecurityPin ? 'Update PIN' : 'Save PIN', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _promptRemovePin() async {
    final currentPinController = TextEditingController();
    String dialogError = '';
    bool isRemoving = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: const Row(
              children: [
                Icon(Icons.lock_open_rounded, color: AppColors.warning),
                SizedBox(width: 8),
                Text('Disable Access PIN', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Disabling PIN protection means anyone with access to this computer can open the application without a passcode.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: currentPinController,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Enter Current 4-Digit PIN to Confirm',
                      counterText: '',
                      isDense: true,
                    ),
                  ),
                  if (dialogError.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      dialogError,
                      style: const TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isRemoving ? null : () => Navigator.pop(dialogCtx),
                child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warning,
                  foregroundColor: Colors.white,
                ),
                onPressed: isRemoving
                    ? null
                    : () async {
                        final currentPin = currentPinController.text.trim();
                        if (currentPin.length != 4) {
                          setDialogState(() => dialogError = 'Please enter your current 4-digit PIN.');
                          return;
                        }

                        setDialogState(() {
                          isRemoving = true;
                          dialogError = '';
                        });

                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          final db = Provider.of<AppDatabase>(context, listen: false);
                          final pinService = SecurityPinService(db);
                          final isValid = await pinService.verifyPin(currentPin);

                          if (!isValid) {
                            setDialogState(() {
                              isRemoving = false;
                              dialogError = 'Current PIN is incorrect.';
                            });
                            return;
                          }

                          await pinService.removePin();
                          if (dialogCtx.mounted) Navigator.pop(dialogCtx);

                          setState(() => _hasSecurityPin = false);
                          if (mounted) {
                            messenger.showSnackBar(
                              const SnackBar(
                                backgroundColor: AppColors.success,
                                content: Text('Security PIN removed. Lock screen disabled.'),
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() {
                            isRemoving = false;
                            dialogError = 'Failed to remove PIN: $e';
                          });
                        }
                      },
                child: isRemoving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Disable PIN Protection', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Company Profile & System Settings', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 820),
                    child: Column(
                      children: [
                        // Card 1: Company Profile Info & Logo Management
                        Form(
                          key: _formKey,
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.business_rounded, color: AppColors.primary),
                                        SizedBox(width: 8),
                                        Text('Own Company Details & Branding', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                                      ],
                                    ),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      ),
                                      icon: const Icon(Icons.save_rounded, size: 16),
                                      label: const Text('Save Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      onPressed: _saveSettings,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),

                                // Logo Row
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceSecondary,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 72,
                                        height: 72,
                                        decoration: BoxDecoration(
                                          color: AppColors.surface,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: AppColors.borderStrong),
                                        ),
                                        child: _logoPath != null && File(_logoPath!).existsSync()
                                            ? ClipRRect(
                                                borderRadius: BorderRadius.circular(8),
                                                child: Image.file(File(_logoPath!), fit: BoxFit.contain),
                                              )
                                            : const Icon(Icons.image_outlined, color: AppColors.textMuted, size: 32),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('Company Logo', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                                            const SizedBox(height: 4),
                                            Text(
                                              _logoPath != null ? 'Logo is active and will appear on all bills, receipts, and PDF prints.' : 'No logo uploaded. Add your company emblem for bills and receipts.',
                                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppColors.primary,
                                          side: const BorderSide(color: AppColors.borderStrong),
                                        ),
                                        icon: const Icon(Icons.file_upload_outlined, size: 16),
                                        label: Text(_logoPath != null ? 'Change Logo' : 'Select Logo', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                        onPressed: _pickLogo,
                                      ),
                                      if (_logoPath != null) ...[
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                                          tooltip: 'Remove Logo',
                                          onPressed: _removeLogo,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),

                                _profileField(
                                  label: 'Company / Firm / Business Name *',
                                  initialValue: _companyName,
                                  isRequired: true,
                                  onSaved: (v) => _companyName = v!.trim(),
                                ),
                                const SizedBox(height: 14),
                                _profileField(
                                  label: 'Complete Business Address',
                                  initialValue: _address,
                                  maxLines: 2,
                                  onSaved: (v) => _address = v?.trim() ?? '',
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _profileField(
                                        label: 'Phone / Mobile',
                                        initialValue: _phone,
                                        onSaved: (v) => _phone = v?.trim() ?? '',
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _profileField(
                                        label: 'Email Address',
                                        initialValue: _email,
                                        onSaved: (v) => _email = v?.trim() ?? '',
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                _profileField(
                                  label: 'GSTIN / Tax Registration Number',
                                  initialValue: _taxNumber,
                                  onSaved: (v) => _taxNumber = v?.trim() ?? '',
                                ),
                                const SizedBox(height: 14),
                                _profileField(
                                  label: 'Bank Account Details (printed on invoice footer)',
                                  initialValue: _bankDetails,
                                  maxLines: 2,
                                  onSaved: (v) => _bankDetails = v?.trim() ?? '',
                                ),
                                const SizedBox(height: 14),
                                _profileField(
                                  label: 'Terms & Conditions (printed on invoices)',
                                  initialValue: _termsAndConditions,
                                  maxLines: 3,
                                  onSaved: (v) => _termsAndConditions = v?.trim() ?? '',
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Card: Security & Access PIN
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.shield_outlined, color: AppColors.primary),
                                      SizedBox(width: 8),
                                      Text('Security & Access Passcode', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _hasSecurityPin ? AppColors.successBg : AppColors.surfaceSecondary,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: _hasSecurityPin ? AppColors.success.withValues(alpha: 0.4) : AppColors.border,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _hasSecurityPin ? Icons.lock_rounded : Icons.lock_open_rounded,
                                          size: 14,
                                          color: _hasSecurityPin ? AppColors.success : AppColors.textMuted,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          _hasSecurityPin ? 'PIN Protection Active' : 'No PIN Configured',
                                          style: TextStyle(
                                            color: _hasSecurityPin ? AppColors.success : AppColors.textMuted,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _hasSecurityPin
                                    ? 'A 4-digit PIN is required each time the application starts up to safeguard financial records.'
                                    : 'Protect your financial records from unauthorized local access by enabling a 4-digit startup PIN.',
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
                              ),
                              const SizedBox(height: 18),
                              Row(
                                children: [
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                    ),
                                    icon: const Icon(Icons.password_rounded, size: 18),
                                    label: Text(
                                      _hasSecurityPin ? 'Change Access PIN' : 'Set Up Access PIN',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    onPressed: _promptChangePin,
                                  ),
                                  if (_hasSecurityPin) ...[
                                    const SizedBox(width: 12),
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.error,
                                        side: const BorderSide(color: AppColors.borderStrong),
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      ),
                                      icon: const Icon(Icons.lock_open_rounded, size: 18),
                                      label: const Text('Disable PIN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      onPressed: _promptRemovePin,
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Card 2: Database Health & Backups
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.storage_rounded, color: AppColors.primary),
                                      SizedBox(width: 8),
                                      Text('Database Diagnostics & Backups', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                                    ],
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
                                    onPressed: _loadHealthInfo,
                                    tooltip: 'Refresh Status',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),

                              if (_healthInfo != null) ...[
                                if (_diagnosticReport != null)
                                  _buildHealthDetailRow('Diagnostic Status', _diagnosticReport!.isHealthy ? 'PASSED (0 Issues)' : 'FAILED (${_diagnosticReport!.failedChecks.length} Issues)'),
                                _buildHealthDetailRow('Database Path', _healthInfo!.dbPath),
                                _buildHealthDetailRow('Database Size', '${(_healthInfo!.dbSizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB'),
                                _buildHealthDetailRow('Schema Version', 'v${_healthInfo!.schemaVersion}'),
                                _buildHealthDetailRow('Journal Mode (WAL)', _healthInfo!.journalMode),
                                _buildHealthDetailRow('Foreign Keys Enabled', _healthInfo!.foreignKeysEnabled ? 'YES (Active)' : 'NO'),
                                _buildHealthDetailRow('Integrity Status', _healthInfo!.integrityStatus),
                                _buildHealthDetailRow('Total Invoices / Vouchers', '${_healthInfo!.totalInvoices} / ${_healthInfo!.totalVouchers}'),
                                _buildHealthDetailRow('Total Stock Items / Ledgers', '${_healthInfo!.totalStockItems} / ${_healthInfo!.totalLedgers}'),
                                _buildHealthDetailRow(
                                  'Last Verified Backup',
                                  _healthInfo!.lastBackup != null
                                      ? '${_healthInfo!.lastBackup!.fileName} (${(_healthInfo!.lastBackup!.fileSizeBytes / 1024).toStringAsFixed(1)} KB)'
                                      : 'No backups recorded',
                                ),
                              ] else ...[
                                const Center(child: CircularProgressIndicator()),
                              ],

                              const SizedBox(height: 20),

                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.textPrimary,
                                        side: const BorderSide(color: AppColors.borderStrong),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                      icon: _isDiagnosticRunning 
                                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                                          : const Icon(Icons.health_and_safety_rounded, color: AppColors.success, size: 18),
                                      label: const Text('Run Integrity Check', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      onPressed: _isDiagnosticRunning ? null : _runIntegrityCheck,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                      icon: const Icon(Icons.backup_rounded, size: 18),
                                      label: const Text('Backup Now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      onPressed: _triggerBackup,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.primary,
                                        side: const BorderSide(color: AppColors.borderStrong),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                      icon: const Icon(Icons.verified_rounded, size: 18),
                                      label: const Text('Verify Backup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      onPressed: _healthInfo?.lastBackup != null ? _verifyLastBackup : null,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Card 3: Danger Zone / Data Reset
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppColors.errorBg.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.error.withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded, color: AppColors.error),
                                  SizedBox(width: 8),
                                  Text('Danger Zone: Data Reset', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 16)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Clear transaction history (bills, payments, receipts, stock movements) while preserving your company details, address, and logo.',
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.error,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                ),
                                icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                                label: const Text('Reset Business Data...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                onPressed: _promptDataReset,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildHealthDetailRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileField({
    required String label,
    required String? initialValue,
    required void Function(String?) onSaved,
    bool isRequired = false,
    int maxLines = 1,
  }) {
    return TextFormField(
      initialValue: initialValue,
      maxLines: maxLines,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
      ),
      validator: isRequired
          ? (val) => val == null || val.trim().isEmpty ? 'Required field' : null
          : null,
      onSaved: onSaved,
    );
  }
}
