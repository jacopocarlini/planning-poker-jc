import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

// Helper function to create a MaterialColor from a single Color.
// This is useful because ThemeData often expects a MaterialColor (a swatch)
// for the primary color, but modern design often uses a specific primary shade.
MaterialColor createMaterialColor(Color color) {
  List strengths = <double>[.05];
  Map<int, Color> swatch = {};
  final int r = color.red, g = color.green, b = color.blue;

  for (int i = 1; i < 10; i++) {
    strengths.add(0.1 * i);
  }
  for (var strength in strengths) {
    final double ds = 0.5 - strength;
    swatch[(strength * 1000).round()] = Color.fromRGBO(
      r + ((ds < 0 ? r : (255 - r)) * ds).round(),
      g + ((ds < 0 ? g : (255 - g)) * ds).round(),
      b + ((ds < 0 ? b : (255 - b)) * ds).round(),
      1,
    );
  }
  return MaterialColor(color.value, swatch);
}


// --- Define Custom Colors based on the screenshot ---
// Using hex codes often gives more precision than named Material colors.
// Use a color picker tool on the screenshot for best results.
const Color primaryBlue = Color(0xFF4A90E2); // Main blue from banner/buttons
const Color lightBlue = Color(0xFF5D9FEC);
const Color lightBlueGrey = Color(0xFF9EC5F1);
const Color lightGreyBackground = Color(0xFFF8F9FA); // Very light main background
const Color cardWhite = Colors.white;
const Color darkText = Color(0xFF4A4A4A); // Dark grey for text
const Color lightGrey = Color(0xFFB1B1B1); // Lighter grey for timestamps etc.
const Color secondaryText = Color(0xFF9B9B9B); // Lighter grey for timestamps etc.
const Color accentYellow = Color(0xFFF8B64C); // Yellow for progress bars/highlights
const Color accentOrange = Color(0xFFF5A623); // Orange for 'NEW' tags (or use a brighter one)
const Color inputFillColor = Color(0xFFF2F2F7); // Light fill for search bar


// --- Custom ThemeData ---
final ThemeData appThemeData = ThemeData(
  // Use Material 3 features
  useMaterial3: true,

  // Define the color scheme - this is the modern way
  colorScheme: ColorScheme.light(
    primary: primaryBlue,
    onPrimary: Colors.white, // Text/icons on primary color
    secondary: accentYellow, // Used for highlights, progress bars
    onSecondary: darkText, // Text/icons on secondary color
    background: lightGreyBackground, // Overall background
    onBackground: darkText, // Text/icons on background
    surface: cardWhite, // Card backgrounds, dialogs etc.
    onSurface: darkText, // Text/icons on surface color
    error: Colors.redAccent,
    onError: Colors.white,
    brightness: Brightness.light,
    // Define other colors if needed, e.g., surface variants
    surfaceVariant: lightGreyBackground, // Can use for sidebars etc.
    onSurfaceVariant: darkText,
    outline: Colors.grey.shade300, // Default outline color
  ),

  // Fallback (less critical if colorScheme is well-defined)
  primarySwatch: createMaterialColor(primaryBlue), // Create swatch from primaryBlue
  primaryColor: primaryBlue, // Still useful for some older widgets

  // Font
  fontFamily: 'Poppins', // Poppins or Inter look closer than Roboto in the screenshot
  // Make sure to add the font to pubspec.yaml and assets!
  // If you prefer Roboto, change it back here.

  // Scaffold Background
  scaffoldBackgroundColor: lightGreyBackground,

  // AppBar Theme (Not a traditional AppBar in screenshot, but define basics)
  appBarTheme: const AppBarTheme(
    backgroundColor: cardWhite, // Or lightGreyBackground depending on usage
    foregroundColor: darkText, // Color for icons and title
    elevation: 0, // No shadow like in the screenshot header
    surfaceTintColor: Colors.transparent, // M3 tint prevention
    iconTheme: IconThemeData(color: darkText),
    titleTextStyle: TextStyle(
      color: darkText,
      fontSize: 18,
      fontWeight: FontWeight.w600,
      fontFamily: 'Poppins', // Ensure consistency
    ),
  ),

  // Text Theme
  textTheme: const TextTheme(
    // Headlines
    headlineLarge: TextStyle(color: darkText, fontWeight: FontWeight.w600, fontSize: 28),
    headlineMedium: TextStyle(color: darkText, fontWeight: FontWeight.w600, fontSize: 24),
    headlineSmall: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold, fontSize: 20), // e.g., "Welcome back"

    // Titles (Event names etc.)
    titleLarge: TextStyle(color: darkText, fontWeight: FontWeight.w600, fontSize: 18), // Event Titles
    titleMedium: TextStyle(color: darkText, fontWeight: FontWeight.w500, fontSize: 16),
    titleSmall: TextStyle(color: darkText, fontWeight: FontWeight.w500, fontSize: 14),

    // Body (Standard text)
    bodyLarge: TextStyle(color: darkText, fontSize: 16, height: 1.4),
    bodyMedium: TextStyle(color: darkText, fontSize: 14, height: 1.4), // Default text
    bodySmall: TextStyle(color: secondaryText, fontSize: 12, height: 1.3), // Timestamps, answers left

    // Labels (Buttons, captions)
    labelLarge: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500), // Button text
    labelMedium: TextStyle(color: darkText, fontSize: 12),
    labelSmall: TextStyle(color: secondaryText, fontSize: 11),
  ).apply( // Apply base color if needed, though ColorScheme handles most
    bodyColor: darkText,
    displayColor: darkText,
  ),

  // Card Theme
  cardTheme: CardTheme(
    color: cardWhite,
    elevation: 0.5, // Very subtle shadow or 0
    // shadowColor: Colors.grey.withOpacity(0.1), // Subtle shadow color
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12.0), // Consistent rounded corners
      // side: BorderSide(color: Colors.grey.shade200, width: 0.5), // Optional subtle border
    ),
    margin: const EdgeInsets.symmetric(vertical: 8.0), // Default margin
  ),

  // ElevatedButton Theme (e.g., "Answer questions")
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: primaryBlue,
      foregroundColor: Colors.white, // Text color
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), // Generous padding
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, fontFamily: 'Poppins'),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0), // Slightly less round than cards?
      ),
      elevation: 2, // Small elevation
      shadowColor: primaryBlue.withOpacity(0.3),
    ),
  ),

  // TextButton Theme (For things that look like links)
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: primaryBlue, // Link color
      textStyle: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Poppins'),
      padding: EdgeInsets.zero, // Adjust as needed
    ),
  ),


  // Input Decoration Theme (Search bar)
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: inputFillColor, // Very light grey fill
    hintStyle: TextStyle(color: secondaryText.withOpacity(0.8), fontSize: 14),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder( // Default state (no focus)
      borderRadius: BorderRadius.circular(10.0),
      borderSide: BorderSide.none, // No border by default for filled style
    ),
    enabledBorder: OutlineInputBorder( // Explicitly no border when enabled
      borderRadius: BorderRadius.circular(10.0),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder( // Border appears on focus
      borderRadius: BorderRadius.circular(10.0),
      borderSide: BorderSide(color: primaryBlue, width: 1.5), // Primary color border on focus
    ),
    // Prefix icon color can be set here if needed
    prefixIconColor: secondaryText,
    iconColor: secondaryText, // General icon color
  ),

  // Chip Theme (For 'NEW' tags)
  chipTheme: ChipThemeData(
    backgroundColor: accentOrange,
    labelStyle: const TextStyle(
        color: Colors.white,
        fontSize: 10,
        fontWeight: FontWeight.bold,
        fontFamily: 'Poppins'
    ),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(6.0),
    ),
    side: BorderSide.none,
  ),

  // TabBar Theme (For 'My events', 'Invites', 'Archive')
  tabBarTheme: TabBarTheme(
    indicator: UnderlineTabIndicator(
      borderSide: BorderSide(color: accentYellow, width: 3.0), // Yellow underline
      insets: EdgeInsets.symmetric(horizontal: 16.0), // Adjust underline length
    ),
    indicatorSize: TabBarIndicatorSize.label, // Underline matches label width
    labelColor: darkText, // Color of selected tab text
    unselectedLabelColor: secondaryText, // Color of unselected tab text
    labelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, fontFamily: 'Poppins'),
    unselectedLabelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, fontFamily: 'Poppins'),
    overlayColor: MaterialStateProperty.all(primaryBlue.withOpacity(0.1)), // Ripple effect
  ),

  // Progress Indicator Theme
  progressIndicatorTheme: ProgressIndicatorThemeData(
    color: accentYellow, // Main progress color
    linearTrackColor: Colors.grey.shade300, // Background track color
    linearMinHeight: 6, // Thickness of the bar
    // Consider circular progress color too if needed
    // circularTrackColor: Colors.grey.shade300,
  ),

  // Icon Theme
  iconTheme: IconThemeData(
    color: secondaryText, // Default icon color (can be overridden)
    size: 24,
  ),

  // List Tile Theme (For Activity Feed items)
  listTileTheme: ListTileThemeData(
    leadingAndTrailingTextStyle: TextStyle(color: secondaryText, fontSize: 12, fontFamily: 'Poppins'), // Timestamps
    titleTextStyle: TextStyle(color: darkText, fontSize: 14, fontWeight: FontWeight.w500, fontFamily: 'Poppins'), // Main text
    subtitleTextStyle: TextStyle(color: secondaryText, fontSize: 13, fontFamily: 'Poppins'),
    iconColor: secondaryText,
    minLeadingWidth: 40, // Ensure enough space for avatar
  ),

  // Dialog Theme
  dialogTheme: DialogTheme(
    backgroundColor: cardWhite,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12.0),
    ),
    titleTextStyle: TextStyle(color: darkText, fontSize: 18, fontWeight: FontWeight.w600, fontFamily: 'Poppins'),
    contentTextStyle: TextStyle(color: darkText, fontSize: 14, height: 1.4, fontFamily: 'Poppins'),
  ),

  scrollbarTheme: const ScrollbarThemeData(
    thumbVisibility: WidgetStatePropertyAll(true),
  ),
  dividerColor: CupertinoColors.lightBackgroundGray
);