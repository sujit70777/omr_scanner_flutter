/// A fixed sheet layout, measured once from a reference scan and baked into
/// the app. Because your sheet format never changes, the app does not need
/// the user to calibrate anything — it finds the sheet's own printed
/// registration marks in each photo and maps this template onto them.
///
/// All coordinates are NORMALISED against the registration anchors:
///   u = 0 at the left-most timing mark, u = 1 at the right-most
///   v = 0 at the top timing-mark row, v = 1 at the bottom timing-mark row
/// Values outside 0..1 are legal (the roll-number block sits above the top
/// band, so its v values are negative).
class AnswerColumn {
  final int startQuestion;
  final int questionCount;
  final List<double> optionU; // normalised x of each option bubble

  const AnswerColumn({
    required this.startQuestion,
    required this.questionCount,
    required this.optionU,
  });
}

class SheetTemplate {
  final String name;
  final int optionsCount;
  final int totalQuestions;

  /// Normalised y of each answer row (shared by every column).
  final List<double> rowV;
  final List<AnswerColumn> columns;
  final double bubbleRadiusU;

  /// Roll-number block: [digitColumnU] x [digitRowV], digit 0 at row index 0.
  final List<double> rollColumnU;
  final List<double> rollRowV;
  final double rollBubbleRadiusU;

  /// Page width/height, used to shape the live-camera guide frame.
  final double pageAspectRatio;

  const SheetTemplate({
    required this.name,
    required this.optionsCount,
    required this.totalQuestions,
    required this.rowV,
    required this.columns,
    required this.bubbleRadiusU,
    required this.rollColumnU,
    required this.rollRowV,
    required this.rollBubbleRadiusU,
    required this.pageAspectRatio,
  });

  int get rollDigits => rollColumnU.length;
}

/// Measured directly from the supplied reference sheet:
/// 50 questions in 3 columns (1-17, 18-34, 35-50), 4 options each
/// (ক / খ / গ / ঘ), red printing with black timing marks top and bottom
/// of the answer block. Roll bubbles exist on the sheet but are not read —
/// the app only samples the answer grid.
const SheetTemplate kDefaultSheetTemplate = SheetTemplate(
  name: 'Standard 50Q · 4 option',
  optionsCount: 4,
  totalQuestions: 50,
  pageAspectRatio: 0.771,
  bubbleRadiusU: 0.011158,
  rowV: [
    0.209216, 0.257205, 0.301554, 0.346951, 0.391201, 0.436138,
    0.480756, 0.525960, 0.572355, 0.618635, 0.663748, 0.708972,
    0.756085, 0.802394, 0.848284, 0.894569, 0.941318,
  ],
  columns: [
    AnswerColumn(
      startQuestion: 1,
      questionCount: 17,
      optionU: [0.067644, 0.107573, 0.147783, 0.190241],
    ),
    AnswerColumn(
      startQuestion: 18,
      questionCount: 17,
      optionU: [0.368517, 0.407836, 0.447299, 0.488881],
    ),
    AnswerColumn(
      startQuestion: 35,
      questionCount: 16,
      optionU: [0.658867, 0.699129, 0.739821, 0.782705],
    ),
  ],
  rollColumnU: [0.187813, 0.210214, 0.233012, 0.258463, 0.280630, 0.304957],
  rollRowV: [
    -0.346691, -0.319622, -0.291692, -0.263509, -0.235782,
    -0.209674, -0.181694, -0.155434, -0.127505, -0.099626,
  ],
  rollBubbleRadiusU: 0.009152,
);
