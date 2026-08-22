import 'package:flutter/material.dart';

abstract final class AppDesign {
  static const double fontMicro = 11;
  static const double fontCaption = 12;
  static const double fontLabel = 13;
  static const double fontBody = 14;
  static const double fontSubtitle = 15;
  static const double fontSectionTitle = 16;
  static const double fontHeading = 18;
  static const double fontPageTitle = 20;
  static const double fontResult = 24;
  static const double fontMetric = 26;
  static const double fontHeroMetric = 34;

  static const double gapTiny = 4;
  static const double gapXSmall = 6;
  static const double gapSmall = 8;
  static const double gapRegular = 10;
  static const double gapCompact = 12;
  static const double gapItem = 14;
  static const double gapStandard = 16;
  static const double gapContent = 18;
  static const double gapMedium = 20;
  static const double gapLarge = 22;
  static const double gapSection = 24;
  static const double gapWide = 26;
  static const double gapLoose = 28;
  static const double gapBetweenCards = 22;
  static const double gapBetweenSections = 28;

  static const double radiusSmall = 8;
  static const double radiusCompact = 12;
  static const double radiusItem = 14;
  static const double radiusControl = 16;
  static const double radiusInput = 18;
  static const double radiusPanel = 20;
  static const double radiusCard = 22;
  static const double radiusDialog = 24;
  static const double bodyLineHeight = 1.4;
  static const double cardTitleLetterSpacing = 1.6;
  static const double cardSubtitleLetterSpacing = 0.9;
  static const double sectionTitleLetterSpacing = 3;
  static const double contentMaxWidth = 600;
  static const double standardControlHeight = 58;
  static const double listLeadingSize = 36;
  static const double chartDonutSize = 136;
  static const double cameraFrameMaxWidth = 320;
  static const double cameraFrameHeight = 120;
  static const double cameraCaptureSize = 82;
  static const double cameraCaptureBusySize = 74;
  static const double chatbotButtonSize = 58;
  static const double chatbotScreenMargin = 18;
  static const double chatbotBottomClearance = 145;

  static const double topBarIconBoxSize = 52;
  static const double cardHeaderIconSize = 44;
  static const double optionBadgeSize = 32;
  static const double compactMetricIconSize = 34;
  static const double topBarActionIconSize = 28;
  static const double sectionIconSize = 30;
  static const double listIconSize = 22;
  static const double footerIconSize = 20;
  static const double resultIconSize = 54;
  static const double footerIconGap = 24;
  static const double emptyStateIconSize = 48;
  static const double actionIconSize = 42;
  static const double scannerIconSize = 88;
  static const double metricIconSize = 34;
  static const double smallActionIconSize = 18;

  static const EdgeInsets pagePadding = EdgeInsets.fromLTRB(24, 22, 24, 8);
  static const EdgeInsets topBarPadding = EdgeInsets.fromLTRB(20, 18, 20, 14);
  static const EdgeInsets bottomNavigationPadding = EdgeInsets.symmetric(
    vertical: 14,
    horizontal: 18,
  );
  static const EdgeInsets cardPadding = EdgeInsets.all(20);
  static const EdgeInsets cardHeaderPadding = EdgeInsets.all(20);
  static const EdgeInsets itemPadding = EdgeInsets.all(14);
  static const EdgeInsets controlPadding = EdgeInsets.symmetric(
    horizontal: 20,
    vertical: 16,
  );
  static const EdgeInsets listItemPadding = EdgeInsets.symmetric(
    horizontal: 18,
    vertical: 16,
  );
  static const EdgeInsets chipPadding = EdgeInsets.symmetric(
    horizontal: 12,
    vertical: 8,
  );
  static const EdgeInsets buttonPadding = EdgeInsets.symmetric(
    horizontal: 18,
    vertical: 14,
  );
  static const EdgeInsets topBarIconPadding = EdgeInsets.all(8);
  static const EdgeInsets gridCellMargin = EdgeInsets.all(4);
  static const EdgeInsets statusBadgePadding = EdgeInsets.symmetric(
    horizontal: 14,
    vertical: 10,
  );
  static const EdgeInsets sectionTitlePadding = EdgeInsets.only(bottom: 16);
  static const EdgeInsets linePadding = EdgeInsets.only(bottom: 8);
  static const EdgeInsets optionPadding = EdgeInsets.only(bottom: 10);
  static const EdgeInsets chartLabelPadding = EdgeInsets.only(bottom: 14);
  static const EdgeInsets detailsSheetMargin = EdgeInsets.fromLTRB(
    16,
    16,
    16,
    125,
  );
  static const EdgeInsets detailsSheetPadding = EdgeInsets.fromLTRB(
    22,
    22,
    22,
    8,
  );
}
