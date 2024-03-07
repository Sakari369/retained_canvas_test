// Sample code for trying to draw circle continuously into an image by using
// PictureRecorder to record a single circle draw, then creating an image out of that
// and on the next draw iteration drawing that created image as background for the next round.

// Seems that one or other of the images are not released, dart memory usage shows the same,
// but process memory is continuously increasing.

// -- Sakari Lehtonen (Sakari369 @ github)

import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:ui' as ui;

Size viewportSize = const Size(1080.0, 810.0);

void main() {
  runApp(MyApp());
}

// Create empty image filled with single color.
ui.Image createColoredImage(int width, int height, ui.Color color) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  // Fill the canvas with the specified color
  final paint = Paint()..color = color;
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    paint,
  );

  // Convert canvas to image
  final picture = recorder.endRecording();

  return picture.toImageSync(width, height);
}

class MyApp extends StatelessWidget {
  @override

  Widget build(BuildContext context) {
    viewportSize = MediaQuery.of(context).size;
    print("Got viewport size of " + viewportSize.toString());

    return MaterialApp(
      title: 'Tracing test',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark,
      ),
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  late ui.Image image = createColoredImage(1080, 810, const Color.fromARGB(0, 0, 0, 0));

  final double _radius = 50;

  double _scaling = 1.0;
  double _scalePhase = 0;
  final double _scaleVelocity = 0.0005;

  late AnimationController _animController;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..addListener(() {
      Duration? lastElapsedDuration = _animController.lastElapsedDuration;
      // This will be null if the animation is not running.
      if (lastElapsedDuration == null) {
        return;
      }

      // Update scaling.
      _scalePhase += _scaleVelocity;
      _scaling = sin(_scalePhase) / 2*pi;

      Size size = viewportSize;

      // Use PictureRecorder to record drawing a single circle.
      // The idea is here, that we setup the recording, then call

      // TracingPainter to draw the circle.
      // After we have first time drawn the circle, we convert that into an image.
      // Now, next time we draw, and we have that image, we first draw that image, then draw the single circle on top of that.

      // When we convert that combined drawing of the previous image and the new circle into an image,
      // and continue this cycle, we should get an tracing like effect where the previous shapes are blended and draw
      // on top of each other.

      // But this crashes, memory for one or the other image is not freed correctly in the underlying implementation it seems.

      ui.PictureRecorder recorder = ui.PictureRecorder();
      ui.Canvas canvas = ui.Canvas(recorder);

      TracingPainter(image, _scaling, _radius).paint(canvas, size);

      ui.Picture picture = recorder.endRecording();

      // Generate an image out of the recorded picture.
      // And re-assign the the previous image.
      image = picture.toImageSync(
        (size.width).ceil(),
        (size.height).ceil(),
      );

      setState(() {});
    });

    _animController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    image.dispose();
    super.dispose();
  }

  void clear() {
    setState(() {
      image.dispose();
      image = createColoredImage(1080, 810, const Color.fromARGB(255, 0, 0, 0));
    });
  }

  @override
  build(context) =>
      Scaffold(
        body: LayoutBuilder(builder: (context, constraints) {
          var size = constraints.constrain(Size.infinite);
          return CustomPaint(
              size: size,

              // This does not actually paint anything.
              painter: BackgroundPainter(),

              // For blending the draw contents into the background with a screen blending mode.
              child: ShaderMask(
                shaderCallback: (Rect bounds) {
                  return const LinearGradient(
                    colors: [Color(0xff009688), Color(0xffe91e63), Color(0xffffc800)],
                    stops: [0.25, 0.75, 0.87],
                    begin: Alignment.bottomRight,
                    end: Alignment.topLeft,
                  ).createShader(bounds);
                },

                blendMode: BlendMode.screen,

                child: CustomPaint(
                  painter: TracingPainter(image, _scaling, _radius),
                  size: size,
                  willChange: true,
                ),
              )
          );
        }),
      );
}

class TracingPainter extends CustomPainter {
  final ui.Image image;
  final double scaling;
  final double radius;

  TracingPainter(this.image, this.scaling, this.radius);

  @override void dispose() {
    image.dispose();
  }

  @override paint(canvas, size) {

    // If the painter was passed an image, that this first as the background image.
    if (image != null) {
      canvas.drawImageRect(
          image,
          Offset.zero & Size(image.width.toDouble(), image.height.toDouble()),
          Offset.zero & size,
          Paint()
      );
    }

    Paint circlePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..blendMode = BlendMode.srcOver
      ..color = const Color.fromARGB(64, 255, 255, 255);

    Offset center = Offset(size.width/2.0, size.height/2.0);

    canvas.save();
    canvas.scale(scaling, scaling);
    canvas.drawCircle(center, 300, circlePaint);
    canvas.restore();
  }

  shouldRepaint(TracingPainter old) => true;
}

class BackgroundPainter extends CustomPainter {
  @override paint(canvas, size) {
  }

  shouldRepaint(BackgroundPainter old) => true;
}
