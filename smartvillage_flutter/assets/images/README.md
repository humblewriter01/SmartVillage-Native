# Illustration assets

The UI currently draws its own artwork (`lib/widgets/leaf_illustration.dart`
paints the crop leaves with `CustomPainter`, and the launcher icon is a vector
drawable in `android/app/src/main/res/drawable`), so no bitmaps are required at
runtime.

Keep this file here so the declared asset directory is not empty — Flutter
fails the build when a folder listed under `flutter: assets:` contains no
files. Any photo or logo added later can simply be dropped in next to it and
referenced with `Image.asset('assets/images/<name>')`.
