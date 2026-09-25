import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:crypto/crypto.dart';
import '../data/database.dart';
import '../core/security_pin_service.dart';
import '../main.dart'; // To access the main app frame after unlock

class SecurityLockPage extends StatefulWidget {
  const SecurityLockPage({super.key});

  @override
  State<SecurityLockPage> createState() => _SecurityLockPageState();
}

class _SecurityLockPageState extends State<SecurityLockPage> {
  final List<int> _enteredDigits = [];
  bool _isSetupMode = false;
  bool _isConfirming = false;
  String _firstEnteredPin = '';
  String _savedPinHash = '';
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _checkPinStatus();
  }

  Future<void> _checkPinStatus() async {
    try {
      final db = Provider.of<AppDatabase>(context, listen: false);
      final pinService = SecurityPinService(db);
      final pinHash = await pinService.getPinHash();
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (pinHash == null || pinHash.isEmpty) {
            _isSetupMode = true;
          } else {
            _savedPinHash = pinHash;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isSetupMode = true;
        });
      }
    }
  }

  String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  void _onKeyPress(int val) {
    if (_enteredDigits.length >= 6) return;
    setState(() {
      _errorMessage = '';
      _enteredDigits.add(val);
    });

    if (_enteredDigits.length >= 4) {
      // Auto-submit 4-digit PINs
      _submitPin();
    }
  }

  void _onBackspace() {
    if (_enteredDigits.isEmpty) return;
    setState(() {
      _errorMessage = '';
      _enteredDigits.removeLast();
    });
  }

  Future<void> _submitPin() async {
    final enteredPin = _enteredDigits.join();
    _enteredDigits.clear();

    if (_isSetupMode) {
      if (!_isConfirming) {
        setState(() {
          _firstEnteredPin = enteredPin;
          _isConfirming = true;
          _errorMessage = '';
        });
      } else {
        if (enteredPin == _firstEnteredPin) {
          // PIN matched, save it
          final db = Provider.of<AppDatabase>(context, listen: false);
          final pinService = SecurityPinService(db);
          await pinService.setPin(enteredPin);
          _navigateToApp();
        } else {
          setState(() {
            _isConfirming = false;
            _firstEnteredPin = '';
            _errorMessage = 'PINs did not match. Start over.';
          });
        }
      }
    } else {
      final hashed = _hashPin(enteredPin);
      if (hashed == _savedPinHash) {
        _navigateToApp();
      } else {
        setState(() {
          _errorMessage = 'Incorrect PIN. Please try again.';
        });
      }
    }
  }

  void _navigateToApp() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const AppNavigationShell()),
    );
  }

  Future<void> _showForgotPinDialog() async {
    final identityController = TextEditingController();
    final newPinController = TextEditingController();
    final confirmPinController = TextEditingController();
    String dialogError = '';
    bool isResetting = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.lock_reset_rounded, color: Color(0xFF2563EB)),
                SizedBox(width: 10),
                Text('Reset Access PIN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Verify your registered business details or master emergency recovery key (9999) to reset your access PIN.',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: identityController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Registered Business Name / Phone / Master Key',
                        hintText: 'e.g. My Business Enterprise or 9999',
                        prefixIcon: Icon(Icons.verified_user_outlined, size: 20),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: newPinController,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      decoration: const InputDecoration(
                        labelText: 'New 4-Digit Access PIN',
                        hintText: '4 numbers',
                        prefixIcon: Icon(Icons.password_rounded, size: 20),
                        counterText: '',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: confirmPinController,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      decoration: const InputDecoration(
                        labelText: 'Confirm New 4-Digit PIN',
                        hintText: 'Repeat 4 numbers',
                        prefixIcon: Icon(Icons.lock_outline_rounded, size: 20),
                        counterText: '',
                        isDense: true,
                      ),
                    ),
                    if (dialogError.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                dialogError,
                                style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12),
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
                onPressed: isResetting ? null : () => Navigator.pop(dialogCtx),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                icon: isResetting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.check_circle_outline_rounded, size: 18),
                label: const Text('Verify & Reset PIN', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: isResetting
                    ? null
                    : () async {
                        final identity = identityController.text.trim();
                        final newPin = newPinController.text.trim();
                        final confirmPin = confirmPinController.text.trim();

                        if (identity.isEmpty) {
                          setDialogState(() => dialogError = 'Please enter your registered business name, phone, or recovery key.');
                          return;
                        }
                        if (newPin.length != 4 || int.tryParse(newPin) == null) {
                          setDialogState(() => dialogError = 'New PIN must be exactly 4 digits.');
                          return;
                        }
                        if (newPin != confirmPin) {
                          setDialogState(() => dialogError = 'PINs do not match. Please verify.');
                          return;
                        }

                        setDialogState(() {
                          isResetting = true;
                          dialogError = '';
                        });

                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          final db = Provider.of<AppDatabase>(context, listen: false);
                          final pinService = SecurityPinService(db);
                          final isIdentityValid = await pinService.verifyRecoveryIdentity(identity);

                          if (!isIdentityValid) {
                            setDialogState(() {
                              isResetting = false;
                              dialogError = 'Verification failed. Business details or recovery key incorrect.';
                            });
                            return;
                          }

                          await pinService.setPin(newPin);
                          if (dialogCtx.mounted) Navigator.pop(dialogCtx);

                          if (mounted) {
                            messenger.showSnackBar(
                              const SnackBar(
                                backgroundColor: Color(0xFF059669),
                                content: Text('Security PIN successfully reset! Logging in...'),
                              ),
                            );
                            _navigateToApp();
                          }
                        } catch (e) {
                          setDialogState(() {
                            isResetting = false;
                            dialogError = 'Failed to reset PIN: $e';
                          });
                        }
                      },
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF1E40AF))),
      );
    }

    String titleText = '';
    String subtitleText = '';
    if (_isSetupMode) {
      if (!_isConfirming) {
        titleText = 'Create Access PIN';
        subtitleText = 'Set up a secure passcode to restrict access to your accounts.';
      } else {
        titleText = 'Confirm Access PIN';
        subtitleText = 'Re-enter your passcode to verify correctness.';
      }
    } else {
      titleText = 'Access Locked';
      subtitleText = 'Enter your security passcode to log in.';
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            final keyLabel = event.logicalKey.keyLabel;
            if (keyLabel.length == 1 && int.tryParse(keyLabel) != null) {
              _onKeyPress(int.parse(keyLabel));
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.backspace) {
              _onBackspace();
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.enter) {
              _submitPin();
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              width: 380,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo Icon
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEFF6FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_person_rounded,
                      color: Color(0xFF1E40AF),
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Titles
                  Text(
                    titleText,
                    style: const TextStyle(color: Color(0xFF0F172A), fontSize: 20, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitleText,
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, height: 1.4),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),

                  // Pad circles
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) {
                      final isFilled = index < _enteredDigits.length;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: isFilled ? const Color(0xFF1E40AF) : Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isFilled ? const Color(0xFF1E40AF) : const Color(0xFFCBD5E1),
                            width: 2,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),

                  // Error Message
                  if (_errorMessage.isNotEmpty)
                    Text(
                      _errorMessage,
                      style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13, fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
                    ),
                  const SizedBox(height: 20),

                  // Visual Keypad
                  GridView.count(
                    shrinkWrap: true,
                    crossAxisCount: 3,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 1.35,
                    children: [
                      for (int i = 1; i <= 9; i++) _buildKeyButton(i),
                      // Backspace
                      _buildIconButton(Icons.backspace_rounded, _onBackspace),
                      // Zero
                      _buildKeyButton(0),
                      // Check / Submit
                      _buildIconButton(Icons.check_circle_rounded, _submitPin, color: const Color(0xFF059669)),
                    ],
                  ),

                  // Forgot PIN / Password option
                  if (!_isSetupMode) ...[
                    const SizedBox(height: 16),
                    TextButton.icon(
                      icon: const Icon(Icons.help_outline_rounded, size: 16, color: Color(0xFF64748B)),
                      label: const Text(
                        'Forgot PIN / Password?',
                        style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      onPressed: _showForgotPinDialog,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeyButton(int number) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFF1F5F9),
        foregroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        elevation: 0,
      ),
      onPressed: () => _onKeyPress(number),
      child: Text(
        '$number',
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback action, {Color color = const Color(0xFF64748B)}) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFF1F5F9),
        foregroundColor: color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        elevation: 0,
      ),
      onPressed: action,
      child: Icon(icon, size: 20),
    );
  }
}
