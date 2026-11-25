import 'package:material_ui/material_ui.dart';
import 'package:fsphone/theme/fs_colors.dart';

class DialKey {
  const DialKey(this.digit, this.letters);
  final String digit;
  final String letters;
}

const dialKeys = <DialKey>[
  DialKey('1', ''),
  DialKey('2', 'ABC'),
  DialKey('3', 'DEF'),
  DialKey('4', 'GHI'),
  DialKey('5', 'JKL'),
  DialKey('6', 'MNO'),
  DialKey('7', 'PQRS'),
  DialKey('8', 'TUV'),
  DialKey('9', 'WXYZ'),
  DialKey('*', ''),
  DialKey('0', '+'),
  DialKey('#', ''),
];

class DialPad extends StatelessWidget {
  const DialPad({
    super.key,
    required this.onDigit,
    this.onLongZero,
    this.diameter = 76,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback? onLongZero;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 18,
      childAspectRatio: 1.15,
      children: [
        for (final key in dialKeys)
          _PadButton(
            key: ValueKey('dial-key-${key.digit}'),
            dialKey: key,
            diameter: diameter,
            onTap: () => onDigit(key.digit),
            onLongPress: key.digit == '0' ? onLongZero : null,
          ),
      ],
    );
  }
}

class _PadButton extends StatelessWidget {
  const _PadButton({
    super.key,
    required this.dialKey,
    required this.diameter,
    required this.onTap,
    this.onLongPress,
  });

  final DialKey dialKey;
  final double diameter;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: const Color(0xFFEEF1F5),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          onLongPress: onLongPress,
          child: SizedBox(
            width: diameter,
            height: diameter,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  dialKey.digit,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w500,
                    color: FsColors.ink,
                    height: 1,
                  ),
                ),
                if (dialKey.letters.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      dialKey.letters,
                      style: const TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.1,
                        color: FsColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
