import 'package:flutter/material.dart';

/// Central navigation helper for DLog.
///
/// All normal screen-to-screen navigation should go through this class.
/// This keeps Navigator.push / pop logic in one place and makes it easier
/// to maintain the app as more screens are added.
class DLogNavigation {
  DLogNavigation._();

  /// Opens a new screen on top of the current screen.
  ///
  /// Example:
  /// DLogNavigation.push(
  ///   context,
  ///   const SomeScreen(),
  /// );
  static Future<T?> push<T>(
    BuildContext context,
    Widget screen,
  ) {
    return Navigator.of(context).push<T>(
      MaterialPageRoute<T>(
        builder: (_) => screen,
      ),
    );
  }

  /// Replaces the current screen with a new screen.
  ///
  /// Useful for flows such as:
  /// Login → Home
  /// Onboarding → Home
  static Future<T?> replace<T, TO>(
    BuildContext context,
    Widget screen, {
    TO? result,
  }) {
    return Navigator.of(context).pushReplacement<T, TO>(
      MaterialPageRoute<T>(
        builder: (_) => screen,
      ),
      result: result,
    );
  }

  /// Goes back to the previous screen.
  static void pop<T>(
    BuildContext context, [
    T? result,
  ]) {
    Navigator.of(context).pop<T>(result);
  }

  /// Goes back only if there is a screen available to pop.
  static bool maybePop<T>(
    BuildContext context, [
    T? result,
  ]) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop<T>(result);
      return true;
    }

    return false;
  }

  /// Removes all previous screens until the supplied condition is met,
  /// then opens the new screen.
  ///
  /// Useful for completing major flows such as:
  /// Login → Onboarding → Home
  /// where the user should not be able to press Back and return to login.
  static Future<T?> replaceAll<T>(
    BuildContext context,
    Widget screen,
  ) {
    return Navigator.of(context).pushAndRemoveUntil<T>(
      MaterialPageRoute<T>(
        builder: (_) => screen,
      ),
      (route) => false,
    );
  }
}