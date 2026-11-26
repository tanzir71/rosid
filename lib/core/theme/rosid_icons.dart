import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:rosid/core/theme/app_theme.dart';

/// All 56 stroke icons from `design/icons/` (24x24, `stroke="currentColor"`).
enum RosidIcons {
  alert('alert'),
  back('back'),
  backup('backup'),
  bell('bell'),
  book('book'),
  bundle('bundle'),
  calendar('calendar'),
  camera('camera'),
  check('check'),
  checkCircle('check-circle'),
  chevronDown('chevron-down'),
  chevronLeft('chevron-left'),
  chevronRight('chevron-right'),
  close('close'),
  copy('copy'),
  crop('crop'),
  document('document'),
  drag('drag'),
  edit('edit'),
  file('file'),
  filter('filter'),
  flash('flash'),
  forward('forward'),
  hide('hide'),
  home('home'),
  idCard('id-card'),
  image('image'),
  info('info'),
  land('land'),
  listen('listen'),
  lock('lock'),
  more('more'),
  papers('papers'),
  people('people'),
  phone('phone'),
  pin('pin'),
  play('play'),
  plus('plus'),
  print('print'),
  receipt('receipt'),
  rotate('rotate'),
  save('save'),
  scan('scan'),
  seal('seal'),
  search('search'),
  settings('settings'),
  share('share'),
  shield('shield'),
  swap('swap'),
  tag('tag'),
  text('text'),
  translate('translate'),
  trash('trash'),
  wallet('wallet'),
  wand('wand'),
  watermark('watermark');

  const RosidIcons(this.fileName);

  final String fileName;

  String get assetPath => 'assets/icons/$fileName.svg';
}

/// Renders a Rosid stroke SVG icon tinted with [color] (defaults to
/// `RosidColors.of(context).inkPrimary`).
class RosidIcon extends StatelessWidget {
  const RosidIcon(
    this.icon, {
    super.key,
    this.size = 24,
    this.color,
    this.semanticLabel,
  });

  final RosidIcons icon;
  final double size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? RosidColors.of(context).inkPrimary;
    return SvgPicture.asset(
      icon.assetPath,
      width: size,
      height: size,
      semanticsLabel: semanticLabel,
      colorFilter: ColorFilter.mode(effectiveColor, BlendMode.srcIn),
    );
  }
}
