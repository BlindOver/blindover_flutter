import 'dart:io';
import 'dart:developer';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';

import 'package:blindover_flutter/widgets/large_action_button.dart';
import 'package:blindover_flutter/widgets/large_nudge_card.dart';
import 'package:blindover_flutter/widgets/large_text.dart';
import 'package:blindover_flutter/utilities/palette.dart';
import 'package:blindover_flutter/controllers/picture_controller.dart';

///- [CameraPreviewScreen]은 카메라 미리보기 화면과 캡쳐를 할 수 있습니다.
///- 플러터 에뮬레이터나 iOS 시뮬레이터에서는 동작하지 않습니다.
class CameraPreviewScreen extends StatefulWidget {
  const CameraPreviewScreen({
    Key? key,
    required this.camera,
  }) : super(key: key);

  final CameraDescription camera;

  @override
  State<CameraPreviewScreen> createState() => _CameraPreviewScreenState();
}

class _CameraPreviewScreenState extends State<CameraPreviewScreen>
    with WidgetsBindingObserver {
  /// 카메라 컨트롤러
  late CameraController _cameraController;

  /// 카메라 초기화 비동기 함수
  late Future<void> _initializeCameraControllerFuture;

  late PictureController _pictureController;

  /// 카메라의 정보를 설정하는 변수
  List<CameraDescription>? cameras;

  /// 기본 수치 값
  double currentScale = 1.0;

  /// 포인트 마다 카메라 Zoom In/Out 변경 값
  double currentZoomLevel = 1.0;

  /// 카메라 노출 범위 기본 값
  double currentExposureOffset = 0.0;

  /// 최소로 변경 가능한 Zoom In/Out 값
  double minAvailableZoom = 1.0;

  /// 최대로 변경 가능한 Zoom In/Out 값
  double maxAvailableZoom = 1.0;

  /// 최소로 변경 가능한 노출 범위 값
  double minAvailableExposureOffset = 0.0;

  /// 최대로 변경 가능한 노출 범위 값
  double maxAvailableExposureOffset = 0.0;

  /// 이미지 추론 결과 값
  String output = "--";

  /// 카메라 해상도 설정
  final myResolutionPreset = ResolutionPreset.medium;

  ///- [uploadPictureToServer] 비동기 함수는 임시 저장된 이미지를 서버로 전송합니다.
  Future<String> uploadPictureToServer() async {
    const String url = "http://blindover.duckdns.org/photo";
    final file = File(await _pictureController.getTemporaryPicturePath());
    final dio = Dio();
    try {
      final formData = FormData.fromMap({
        "image": await MultipartFile.fromFile(
          file.path,
          contentType: MediaType("image", "jpeg"),
        ),
      });
      final request = await dio.post(
        url,
        data: formData,
      );
      if (request.statusCode == 200) {
        log("이미지를 서버로 전송하는데 성공했습니다.${request.statusMessage} ${request.data}");
        var data = request.data;
        setState(() {
          output = data;
        });
      } else {
        log("이미지를 서버로 전송하는데 실패했습니다.${request.statusMessage} ${request.data}");
      }
    } on SocketException catch (e) {
      log("서버와 연결이 원활하지 않습니다.${e.message}");
    }
    return "--";
  }

  ///- [capture] 비동기 함수는 사용자가 캡처 버튼을 누르면 실행되는 함수입니다.
  ///- [getTemporaryPicturePath] 비동기 함수를 통해 임시 저장된 이미지의 경로를 가져옵니다.
  ///- [takePictureToTemporaryFile] 비동기 함수를 통해 임시 저장된 이미지를 파일로 저장합니다.
  ///- [uploadPictureToServer] 비동기 함수를 통해 임시 저장된 이미지를 서버로 전송합니다.
  Future<void> capture() async {
    XFile picture;
    try {
      if (_cameraController.value.isInitialized) {
        picture = await _cameraController.takePicture();
        await _pictureController.getTemporaryPicturePath();
        await _pictureController.takePictureToTemporaryFile(picture);
        log("사진을 캡처하는데 성공했습니다.${picture.path}");
        await uploadPictureToServer();
      }
    } on CameraException catch (e) {
      log("카메라를 동작하는데 실패했습니다.${e.code}${e.description}");
    }
  }

  /// 현재 설정된 카메라의 정보를 초기화하는 비동기 함수입니다.
  Future<void> resetCamera() async {
    currentZoomLevel = 1.0;
    currentScale = 1.0;
    currentExposureOffset = 0.0;
  }

  @override
  void initState() {
    super.initState();

    /// 상위 위젯으로부터 받은 카메라 정보로 카메라 컨트롤러를 초기화합니다.
    _cameraController = CameraController(
      widget.camera,
      myResolutionPreset,
    );

    /// 카메라 컨트롤러를 초기화합니다. 이는 Future를 반환합니다.
    _initializeCameraControllerFuture = _cameraController.initialize();

    /// 사진 컨트롤러를 초기화합니다.
    _pictureController = PictureController();
  }

  @override
  void dispose() {
    /// 카메라 위젯으로부터 받은 카메라 정보를 해제합니다.
    if (_cameraController.value.isInitialized) {
      resetCamera();
      _cameraController.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState appLifecycleState) {
    final CameraController cameraController = _cameraController;

    if (!cameraController.value.isInitialized ||
        appLifecycleState == AppLifecycleState.inactive) {
      /// 앱이 비활성화되면 카메라 컨트롤러를 해제합니다.
      cameraController.dispose();
    } else if (appLifecycleState == AppLifecycleState.resumed) {
      /// 앱이 재개되면 카메라 컨트롤러를 다시 초기화합니다.
      _initializeCameraControllerFuture = _cameraController.initialize();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.onSurface,
      body: SafeArea(
        child: FutureBuilder<void>(
          future: _initializeCameraControllerFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Platform.isAndroid
                  ? const CircularProgressIndicator()
                  : const CupertinoActivityIndicator();
            }
            if (snapshot.connectionState == ConnectionState.done) {
              return Column(
                children: [
                  LargeNudgeCard(
                    width: double.infinity,
                    height: 100.0,
                    child: LargeText(words: output),
                  ),
                  Expanded(
                    child: CameraPreview(_cameraController),
                  ),
                  const SizedBox(height: 25.0),
                  LargeActionButton(
                    label: "촬영버튼",
                    words: "촬영하기",
                    onTap: () => capture(),
                  ),
                  const SizedBox(height: 25.0),
                ],
              );
            }
            return Container();
          },
        ),
      ),
    );
  }
}
