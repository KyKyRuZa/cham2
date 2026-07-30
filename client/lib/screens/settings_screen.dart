import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import '../utils/app_localizations.dart';
import '../utils/transitions.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A0E0A),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    AppLocalizations.tr(context, 'settings'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLanguageToggle(context),
                    const SizedBox(height: 24),
                    _buildPolicyButton(context, AppLocalizations.tr(context, 'policy')),
                    const SizedBox(height: 12),
                    _buildPolicyButton(context, AppLocalizations.tr(context, 'policy')),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${AppLocalizations.tr(context, 'app_version')} 1.0.0.0',
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageToggle(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final isEnglish = appState.locale == AppLocale.english;
        return GestureDetector(
          onTap: () => appState.toggleLocale(),
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFFF5C518),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Center(
              child: Text(
                isEnglish
                    ? AppLocalizations.tr(context, 'language_russian')
                    : AppLocalizations.tr(context, 'language_english'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPolicyButton(BuildContext context, String label) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(label),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: Colors.white12,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}