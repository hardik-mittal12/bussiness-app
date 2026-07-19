import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:crypto/crypto.dart';
import '../data/database.dart';
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
    final db = Provider.of<AppDatabase>(context, listen: false);
    final pinRow = await (db.select(db.syncMetadata)..where((t) => t.key.equals('security_pin_hash'))).getSingleOrNull();
    
    setState(() {
      _isLoading = false;
      if (pinRow == null || pinRow.value.isEmpty) {
        _isSetupMode = true;
      } else {
        _savedPinHash = pinRow.value;
      }
    });
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
          final hashed = _hashPin(enteredPin);
          await db.into(db.syncMetadata).insertOnConflictUpdate(
            SyncMetadataCompanion.insert(key: 'security_pin_hash', value: hashed),
          );
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF161928),
        body: Center(child: CircularProgressIndicator(color: Colors.indigoAccent)),
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
      backgroundColor: const Color(0xFF161928),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 380,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2235),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.04)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo Icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.indigoAccent.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_person_rounded,
                    color: Colors.indigoAccent,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Titles
                Text(
                  titleText,
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  subtitleText,
                  style: const TextStyle(color: Colors.white54, fontSize: 13, height: 1.4),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Pad circles
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    final isFilled = index < _enteredDigits.length;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: isFilled ? Colors.indigoAccent : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isFilled ? Colors.indigoAccent : Colors.white24,
                          width: 2,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 24),

                // Error Message
                if (_errorMessage.isNotEmpty)
                  Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: 24),

                // Visual Keypad
                GridView.count(
                  shrinkWrap: true,
                  crossAxisCount: 3,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.3,
                  children: [
                    for (int i = 1; i <= 9; i++) _buildKeyButton(i),
                    // Backspace
                    _buildIconButton(Icons.backspace_rounded, _onBackspace),
                    // Zero
                    _buildKeyButton(0),
                    // Check / Submit
                    _buildIconButton(Icons.check_circle_rounded, _submitPin, color: Colors.greenAccent),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeyButton(int number) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF161928),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
      onPressed: () => _onKeyPress(number),
      child: Text(
        '$number',
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback action, {Color color = Colors.white54}) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF161928),
        foregroundColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
      onPressed: action,
      child: Icon(icon, size: 22),
    );
  }
}
