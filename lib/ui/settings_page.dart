import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/database.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  
  String _companyName = 'Demo Company Pvt Ltd';
  String _taxNumber = '27AAAAA1111A1Z1';
  
  bool _isLoading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final db = Provider.of<AppDatabase>(context, listen: false);
    
    final companyNameRow = await (db.select(db.syncMetadata)..where((t) => t.key.equals('company_name'))).getSingleOrNull();
    final taxNumberRow = await (db.select(db.syncMetadata)..where((t) => t.key.equals('company_tax_no'))).getSingleOrNull();

    setState(() {
      if (companyNameRow != null) _companyName = companyNameRow.value;
      if (taxNumberRow != null) _taxNumber = taxNumberRow.value;
    });
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final db = Provider.of<AppDatabase>(context, listen: false);

    setState(() => _isLoading = true);

    try {
      await db.into(db.syncMetadata).insertOnConflictUpdate(
        SyncMetadataCompanion.insert(key: 'company_name', value: _companyName)
      );
      await db.into(db.syncMetadata).insertOnConflictUpdate(
        SyncMetadataCompanion.insert(key: 'company_tax_no', value: _taxNumber)
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save settings: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF161928),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Application Settings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: _isLoading 
            ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
            : SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 600),
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E2235),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.04)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.business_rounded, color: Colors.indigoAccent),
                              SizedBox(width: 8),
                              Text('Company Profile Info', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          ),
                          const SizedBox(height: 20),
                          
                          // Company Name
                          TextFormField(
                            initialValue: _companyName,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'Registered Company Name',
                              labelStyle: TextStyle(color: Colors.white70),
                              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                            ),
                            validator: (val) => val == null || val.trim().isEmpty ? 'Please enter company name' : null,
                            onSaved: (val) => _companyName = val!.trim(),
                          ),
                          const SizedBox(height: 16),

                          // Tax Registration / GSTIN
                          TextFormField(
                            initialValue: _taxNumber,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'Business Registration / PAN Number',
                              labelStyle: TextStyle(color: Colors.white70),
                              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                            ),
                            onSaved: (val) => _taxNumber = val?.trim() ?? '',
                          ),
                          
                          const SizedBox(height: 32),

                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.indigoAccent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.save_rounded),
                              label: const Text('Save Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              onPressed: _saveSettings,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
