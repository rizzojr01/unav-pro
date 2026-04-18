package com.unav.pathlogic

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.ImageFormat
import android.graphics.Paint
import android.graphics.PixelFormat
import android.graphics.YuvImage
import android.media.Image
import android.opengl.GLES11Ext
import android.opengl.GLES20
import android.opengl.GLSurfaceView
import android.opengl.Matrix
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.Surface
import android.view.View
import android.widget.FrameLayout
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.ar.core.ArCoreApk
import com.google.ar.core.Camera
import com.google.ar.core.CameraConfig
import com.google.ar.core.CameraConfigFilter
import com.google.ar.core.Config
import com.google.ar.core.Coordinates2d
import com.google.ar.core.Frame
import com.google.ar.core.Session
import com.google.ar.core.TrackingFailureReason
import com.google.ar.core.TrackingState
import com.google.ar.core.exceptions.CameraNotAvailableException
import com.google.ar.core.exceptions.NotYetAvailableException
import com.google.ar.core.exceptions.UnavailableApkTooOldException
import com.google.ar.core.exceptions.UnavailableArcoreNotInstalledException
import com.google.ar.core.exceptions.UnavailableDeviceNotCompatibleException
import com.google.ar.core.exceptions.UnavailableSdkTooOldException
import com.google.ar.core.exceptions.UnavailableUserDeclinedInstallationException
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer
import java.util.EnumSet
import java.util.concurrent.CopyOnWriteArraySet
import java.util.concurrent.atomic.AtomicReference
import javax.microedition.khronos.egl.EGLConfig
import javax.microedition.khronos.opengles.GL10
import kotlin.math.atan2
import kotlin.math.max
import kotlin.math.min

class MainActivity : FlutterActivity() {
    private lateinit var arTrackingBridge: AndroidArTrackingBridge

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        arTrackingBridge = AndroidArTrackingBridge(this)
        arTrackingBridge.register(flutterEngine)
    }

    override fun onResume() {
        super.onResume()
        if (::arTrackingBridge.isInitialized) {
            arTrackingBridge.onHostResume()
        }
    }

    override fun onPause() {
        if (::arTrackingBridge.isInitialized) {
            arTrackingBridge.onHostPause()
        }
        super.onPause()
    }

    override fun onDestroy() {
        if (::arTrackingBridge.isInitialized) {
            arTrackingBridge.onHostDestroy()
        }
        super.onDestroy()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        if (::arTrackingBridge.isInitialized &&
            arTrackingBridge.onRequestPermissionsResult(requestCode, grantResults)
        ) {
            return
        }
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }
}

private class AndroidArTrackingBridge(
    private val activity: MainActivity,
) : EventChannel.StreamHandler {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val eventSinkRef = AtomicReference<EventChannel.EventSink?>()
    private val overlaySnapshotRef = AtomicReference(OverlaySnapshot())
    private val sessionLock = Any()
    private val previewViews = CopyOnWriteArraySet<AndroidArPreviewPlatformView>()

    private var session: Session? = null
    private var installRequested = false
    private var pendingStartResult: MethodChannel.Result? = null
    private var pendingCaptureResult: MethodChannel.Result? = null
    private var isSessionRunning = false
    private var primaryRenderer: ArSceneRenderer? = null
    private var latestViewProjectionMatrix: FloatArray? = null

    fun register(flutterEngine: FlutterEngine) {
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        registerChannels(messenger)
        flutterEngine.platformViewsController.registry.registerViewFactory(
            AR_PREVIEW_VIEW_TYPE,
            AndroidArPreviewFactory(this),
        )
    }

    fun onHostResume() {
        if (pendingStartResult != null) {
            continueStartingSession()
        } else if (isSessionRunning) {
            resumeRunningSession()
        }
        previewViews.forEach { it.onHostResume() }
    }

    fun onHostPause() {
        previewViews.forEach { it.onHostPause() }
        pauseSession()
    }

    fun onHostDestroy() {
        stopSession()
        synchronized(sessionLock) {
            session?.close()
            session = null
        }
        primaryRenderer = null
        previewViews.clear()
        pendingCaptureResult = null
        pendingStartResult = null
    }

    fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray): Boolean {
        if (requestCode != CAMERA_PERMISSION_REQUEST_CODE) {
            return false
        }
        if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
            continueStartingSession()
        } else {
            finishPendingStart(
                FlutterErrorPayload(
                    code = "camera_permission_denied",
                    message = "Camera permission is required for ARCore tracking.",
                ),
            )
        }
        return true
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSinkRef.set(events)
    }

    override fun onCancel(arguments: Any?) {
        eventSinkRef.set(null)
    }

    fun registerPreviewView(preview: AndroidArPreviewPlatformView) {
        previewViews.add(preview)
        if (primaryRenderer == null) {
            primaryRenderer = preview.renderer
        }
        synchronized(sessionLock) {
            session?.let { preview.renderer.bindSession(it) }
        }
        if (isSessionRunning) {
            preview.onHostResume()
        }
        preview.requestOverlayRedraw()
    }

    fun unregisterPreviewView(preview: AndroidArPreviewPlatformView) {
        previewViews.remove(preview)
        if (primaryRenderer === preview.renderer) {
            primaryRenderer = previewViews.firstOrNull()?.renderer
            synchronized(sessionLock) {
                session?.let { primaryRenderer?.bindSession(it) }
            }
        }
    }

    fun currentOverlaySnapshot(): OverlaySnapshot = overlaySnapshotRef.get()

    fun currentViewProjectionMatrix(): FloatArray? = latestViewProjectionMatrix?.clone()

    fun currentSurfaceRotation(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            activity.display?.rotation ?: Surface.ROTATION_0
        } else {
            @Suppress("DEPRECATION")
            activity.windowManager.defaultDisplay.rotation
        }
    }

    private fun registerChannels(messenger: BinaryMessenger) {
        MethodChannel(messenger, AR_METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                GET_CAPABILITIES_METHOD -> result.success(buildCapabilities())
                START_SESSION_METHOD -> startSession(result)
                STOP_SESSION_METHOD -> {
                    stopSession()
                    result.success(null)
                }
                CAPTURE_CURRENT_FRAME_METHOD -> captureCurrentFrame(result)
                UPDATE_OVERLAY_METHOD -> {
                    updateOverlay(call.arguments)
                    result.success(null)
                }
                CLEAR_OVERLAY_METHOD -> {
                    clearOverlay()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(messenger, AR_POSE_EVENT_CHANNEL).setStreamHandler(this)
    }

    private fun buildCapabilities(): Map<String, Any> {
        val availability = ArCoreApk.getInstance().checkAvailability(activity)
        return mapOf(
            BACKEND_KEY to ANDROID_ARCORE_BACKEND,
            IS_SUPPORTED_KEY to availability.isSupported,
        )
    }

    private fun startSession(result: MethodChannel.Result) {
        if (pendingStartResult != null) {
            result.error(
                "session_start_in_progress",
                "An ARCore session start is already in progress.",
                null,
            )
            return
        }
        pendingStartResult = result
        continueStartingSession()
    }

    private fun continueStartingSession() {
        val pendingResult = pendingStartResult ?: return
        val availability = ArCoreApk.getInstance().checkAvailability(activity)
        if (availability.isUnsupported) {
            finishPendingStart(
                FlutterErrorPayload(
                    code = "arcore_unsupported",
                    message = "ARCore is unavailable on this device.",
                ),
            )
            return
        }

        try {
            when (ArCoreApk.getInstance().requestInstall(activity, !installRequested)) {
                ArCoreApk.InstallStatus.INSTALL_REQUESTED -> {
                    installRequested = true
                    return
                }
                ArCoreApk.InstallStatus.INSTALLED -> installRequested = false
            }
        } catch (_: UnavailableUserDeclinedInstallationException) {
            finishPendingStart(
                FlutterErrorPayload(
                    code = "arcore_install_declined",
                    message = "ARCore installation was declined by the user.",
                ),
            )
            return
        } catch (_: UnavailableApkTooOldException) {
            finishPendingStart(
                FlutterErrorPayload(
                    code = "arcore_apk_too_old",
                    message = "The installed ARCore services are too old for this app.",
                ),
            )
            return
        }

        if (!hasCameraPermission()) {
            ActivityCompat.requestPermissions(
                activity,
                arrayOf(Manifest.permission.CAMERA),
                CAMERA_PERMISSION_REQUEST_CODE,
            )
            return
        }

        try {
            val localSession = synchronized(sessionLock) {
                session ?: Session(activity).also { created ->
                    configureSession(created)
                    session = created
                    primaryRenderer?.bindSession(created)
                    previewViews.forEach { it.renderer.bindSession(created) }
                }
            }

            primaryRenderer?.onHostResume()
            previewViews.forEach { if (it.renderer !== primaryRenderer) it.onHostResume() }
            localSession.resume()
            isSessionRunning = true
            pendingResult.success(null)
            pendingStartResult = null
        } catch (_: UnavailableArcoreNotInstalledException) {
            finishPendingStart(
                FlutterErrorPayload(
                    code = "arcore_not_installed",
                    message = "ARCore services are not installed on this device.",
                ),
            )
        } catch (_: UnavailableApkTooOldException) {
            finishPendingStart(
                FlutterErrorPayload(
                    code = "arcore_apk_too_old",
                    message = "The installed ARCore services are too old for this app.",
                ),
            )
        } catch (_: UnavailableSdkTooOldException) {
            finishPendingStart(
                FlutterErrorPayload(
                    code = "arcore_sdk_too_old",
                    message = "This app's ARCore SDK is too old for the installed services.",
                ),
            )
        } catch (_: UnavailableDeviceNotCompatibleException) {
            finishPendingStart(
                FlutterErrorPayload(
                    code = "arcore_unsupported",
                    message = "ARCore is unavailable on this device.",
                ),
            )
        } catch (_: SecurityException) {
            finishPendingStart(
                FlutterErrorPayload(
                    code = "camera_permission_denied",
                    message = "Camera permission is required for ARCore tracking.",
                ),
            )
        } catch (_: CameraNotAvailableException) {
            finishPendingStart(
                FlutterErrorPayload(
                    code = "camera_unavailable",
                    message = "The camera is unavailable for ARCore tracking.",
                ),
            )
        } catch (exception: Exception) {
            finishPendingStart(
                FlutterErrorPayload(
                    code = "arcore_start_failed",
                    message = exception.message ?: "Failed to start ARCore tracking.",
                ),
            )
        }
    }

    private fun captureCurrentFrame(result: MethodChannel.Result) {
        if (!isSessionRunning) {
            result.error("frame_unavailable", "ARCore session is not running.", null)
            return
        }
        if (pendingCaptureResult != null) {
            result.error("capture_in_progress", "A frame capture is already in progress.", null)
            return
        }
        pendingCaptureResult = result
        primaryRenderer?.requestFrameCapture() ?: run {
            pendingCaptureResult = null
            result.error("frame_unavailable", "No AR preview is attached for frame capture.", null)
        }
    }

    private fun updateOverlay(arguments: Any?) {
        overlaySnapshotRef.set(parseOverlaySnapshot(arguments))
        previewViews.forEach { it.requestOverlayRedraw() }
    }

    private fun clearOverlay() {
        overlaySnapshotRef.set(OverlaySnapshot())
        previewViews.forEach { it.requestOverlayRedraw() }
    }

    private fun resumeRunningSession() {
        val localSession = synchronized(sessionLock) { session } ?: return
        try {
            primaryRenderer?.onHostResume()
            previewViews.forEach { if (it.renderer !== primaryRenderer) it.onHostResume() }
            localSession.resume()
            isSessionRunning = true
        } catch (_: CameraNotAvailableException) {
            isSessionRunning = false
        }
    }

    private fun stopSession() {
        pendingStartResult = null
        pendingCaptureResult = null
        pauseSession()
    }

    private fun pauseSession() {
        previewViews.forEach { it.onHostPause() }
        synchronized(sessionLock) {
            session?.pause()
        }
        isSessionRunning = false
    }

    private fun configureSession(session: Session) {
        val config = Config(session).apply {
            focusMode = Config.FocusMode.AUTO
            updateMode = Config.UpdateMode.LATEST_CAMERA_IMAGE
        }
        session.configure(config)

        val filter = CameraConfigFilter(session).apply {
            setTargetFps(EnumSet.of(CameraConfig.TargetFps.TARGET_FPS_30))
        }
        val cameraConfig = session
            .getSupportedCameraConfigs(filter)
            .minByOrNull { it.textureSize.width * it.textureSize.height }
            ?: session
                .getSupportedCameraConfigs(CameraConfigFilter(session))
                .minByOrNull { it.textureSize.width * it.textureSize.height }
        if (cameraConfig != null) {
            session.cameraConfig = cameraConfig
        }
    }

    fun handleFrame(frame: Frame, viewportWidth: Int, viewportHeight: Int) {
        emitPoseUpdate(frame.camera)

        val projectionMatrix = FloatArray(16)
        val viewMatrix = FloatArray(16)
        frame.camera.getProjectionMatrix(projectionMatrix, 0, 0.1f, 100f)
        frame.camera.getViewMatrix(viewMatrix, 0)

        val viewProjection = FloatArray(16)
        Matrix.multiplyMM(viewProjection, 0, projectionMatrix, 0, viewMatrix, 0)
        latestViewProjectionMatrix = viewProjection

        previewViews.forEach { it.requestOverlayRedraw() }

        if (pendingCaptureResult != null) {
            completeCapture(frame)
        }
    }

    private fun emitPoseUpdate(camera: Camera) {
        val eventSink = eventSinkRef.get() ?: return
        val pose = camera.pose
        val translation = pose.translation
        val zAxis = pose.zAxis
        val cameraForwardX = -zAxis[0].toDouble()
        val cameraForwardZ = -zAxis[2].toDouble()
        val headingDeg = normalizeDegrees(Math.toDegrees(atan2(-cameraForwardZ, cameraForwardX)))

        val payload = mapOf(
            X_KEY to translation[0].toDouble(),
            Y_KEY to (-translation[2]).toDouble(),
            Z_KEY to translation[1].toDouble(),
            HEADING_KEY to headingDeg,
            CONFIDENCE_KEY to trackingConfidence(camera),
            TIMESTAMP_KEY to System.currentTimeMillis(),
            WORLD_X_KEY to translation[0].toDouble(),
            WORLD_Y_KEY to translation[1].toDouble(),
            WORLD_Z_KEY to translation[2].toDouble(),
            GRAVITY_X_KEY to 0.0,
            GRAVITY_Y_KEY to -1.0,
            GRAVITY_Z_KEY to 0.0,
            INTERFACE_ROTATION_DEG_KEY to currentInterfaceRotationDegrees(),
        )

        mainHandler.post {
            eventSinkRef.get()?.success(payload)
        }
    }

    private fun completeCapture(frame: Frame) {
        val result = pendingCaptureResult ?: return
        try {
            val image = frame.acquireCameraImage()
            val bytes = image.use { encodeYuv420888ToJpeg(it) }
            val correctedBytes = rotateJpegToGravityDown(bytes, requiredCaptureRotationDegrees())
            mainHandler.post {
                pendingCaptureResult?.success(correctedBytes)
                pendingCaptureResult = null
            }
        } catch (_: NotYetAvailableException) {
        } catch (exception: Exception) {
            mainHandler.post {
                pendingCaptureResult?.error(
                    "frame_capture_failed",
                    exception.message ?: "Unable to capture ARCore frame.",
                    null,
                )
                pendingCaptureResult = null
            }
        }
    }

    private fun encodeYuv420888ToJpeg(image: Image): ByteArray {
        val nv21 = yuv420888ToNv21(image)
        val stream = ByteArrayOutputStream()
        val yuvImage = YuvImage(nv21, ImageFormat.NV21, image.width, image.height, null)
        yuvImage.compressToJpeg(
            android.graphics.Rect(0, 0, image.width, image.height),
            95,
            stream,
        )
        return stream.toByteArray()
    }

    private fun rotateJpegToGravityDown(bytes: ByteArray, rotationDegrees: Int): ByteArray {
        if (rotationDegrees % 360 == 0) {
            return bytes
        }

        val source = BitmapFactory.decodeByteArray(bytes, 0, bytes.size) ?: return bytes
        val matrix = android.graphics.Matrix().apply {
            postRotate(rotationDegrees.toFloat())
        }
        val rotated = Bitmap.createBitmap(source, 0, 0, source.width, source.height, matrix, true)
        if (rotated !== source) {
            source.recycle()
        }

        val stream = ByteArrayOutputStream()
        rotated.compress(Bitmap.CompressFormat.JPEG, 95, stream)
        rotated.recycle()
        return stream.toByteArray()
    }

    private fun requiredCaptureRotationDegrees(): Int {
        return when (currentSurfaceRotation()) {
            Surface.ROTATION_0 -> 270
            Surface.ROTATION_90 -> 180
            Surface.ROTATION_180 -> 90
            Surface.ROTATION_270 -> 0
            else -> 270
        }
    }

    private fun yuv420888ToNv21(image: Image): ByteArray {
        val ySize = image.width * image.height
        val uvSize = image.width * image.height / 2
        val nv21 = ByteArray(ySize + uvSize)

        copyPlane(
            image.planes[0].buffer,
            image.planes[0].rowStride,
            image.planes[0].pixelStride,
            image.width,
            image.height,
            nv21,
            0,
            1,
        )

        val uBuffer = image.planes[1].buffer
        val vBuffer = image.planes[2].buffer
        val chromaHeight = image.height / 2
        val chromaWidth = image.width / 2
        val rowStride = image.planes[2].rowStride
        val pixelStride = image.planes[2].pixelStride
        var outputOffset = ySize

        for (row in 0 until chromaHeight) {
            var vIndex = row * rowStride
            var uIndex = row * image.planes[1].rowStride
            for (col in 0 until chromaWidth) {
                nv21[outputOffset++] = vBuffer.get(vIndex)
                nv21[outputOffset++] = uBuffer.get(uIndex)
                vIndex += pixelStride
                uIndex += image.planes[1].pixelStride
            }
        }

        return nv21
    }

    private fun copyPlane(
        buffer: ByteBuffer,
        rowStride: Int,
        pixelStride: Int,
        width: Int,
        height: Int,
        out: ByteArray,
        offset: Int,
        outputStride: Int,
    ) {
        var outputOffset = offset
        val rowData = ByteArray(rowStride)
        for (row in 0 until height) {
            buffer.position(row * rowStride)
            buffer.get(rowData, 0, min(rowStride, rowData.size))
            if (pixelStride == 1 && outputStride == 1) {
                System.arraycopy(rowData, 0, out, outputOffset, width)
                outputOffset += width
            } else {
                var inputOffset = 0
                for (col in 0 until width) {
                    out[outputOffset] = rowData[inputOffset]
                    outputOffset += outputStride
                    inputOffset += pixelStride
                }
            }
        }
    }

    private fun parseOverlaySnapshot(arguments: Any?): OverlaySnapshot {
        val args = arguments as? Map<*, *> ?: return OverlaySnapshot()
        return OverlaySnapshot(
            activePathPoints = parsePointList(args[ACTIVE_PATH_POINTS_KEY]),
            futurePathPoints = parsePointList(args[FUTURE_PATH_POINTS_KEY]),
            nextWaypoint = parsePoint(args[NEXT_WAYPOINT_KEY]),
            destination = parsePoint(args[DESTINATION_KEY]),
        )
    }

    private fun parsePointList(raw: Any?): List<Vector3> {
        val points = raw as? List<*> ?: return emptyList()
        return points.mapNotNull { parsePoint(it) }
    }

    private fun parsePoint(raw: Any?): Vector3? {
        val map = raw as? Map<*, *> ?: return null
        val x = (map[X_KEY] as? Number)?.toFloat() ?: return null
        val y = (map[Y_KEY] as? Number)?.toFloat() ?: return null
        val z = (map[Z_KEY] as? Number)?.toFloat() ?: return null
        return Vector3(x, y, z)
    }

    private fun trackingConfidence(camera: Camera): Double {
        return when (camera.trackingState) {
            TrackingState.TRACKING -> 1.0
            TrackingState.PAUSED -> if (camera.trackingFailureReason == TrackingFailureReason.NONE) 0.5 else 0.25
            TrackingState.STOPPED -> 0.0
            else -> 0.0
        }
    }

    private fun currentInterfaceRotationDegrees(): Double {
        val rotation = currentSurfaceRotation()
        return when (rotation) {
            Surface.ROTATION_90 -> 90.0
            Surface.ROTATION_180 -> 180.0
            Surface.ROTATION_270 -> -90.0
            else -> 0.0
        }
    }

    private fun hasCameraPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            activity,
            Manifest.permission.CAMERA,
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun normalizeDegrees(value: Double): Double {
        var normalized = value % 360.0
        if (normalized < 0) {
            normalized += 360.0
        }
        return normalized
    }

    private fun finishPendingStart(error: FlutterErrorPayload) {
        pendingStartResult?.error(error.code, error.message, null)
        pendingStartResult = null
        isSessionRunning = false
    }

    companion object {
        private const val AR_METHOD_CHANNEL = "unav/tracking/ar_method"
        private const val AR_POSE_EVENT_CHANNEL = "unav/tracking/ar_pose_stream"
        private const val AR_PREVIEW_VIEW_TYPE = "unav/tracking/ar_preview_view"
        private const val CAMERA_PERMISSION_REQUEST_CODE = 9001

        private const val START_SESSION_METHOD = "startSession"
        private const val STOP_SESSION_METHOD = "stopSession"
        private const val GET_CAPABILITIES_METHOD = "getCapabilities"
        private const val CAPTURE_CURRENT_FRAME_METHOD = "captureCurrentFrame"
        private const val UPDATE_OVERLAY_METHOD = "updateOverlay"
        private const val CLEAR_OVERLAY_METHOD = "clearOverlay"

        private const val ANDROID_ARCORE_BACKEND = "androidArCore"
        private const val BACKEND_KEY = "backend"
        private const val IS_SUPPORTED_KEY = "isSupported"
        private const val X_KEY = "x"
        private const val Y_KEY = "y"
        private const val Z_KEY = "z"
        private const val HEADING_KEY = "heading"
        private const val CONFIDENCE_KEY = "confidence"
        private const val TIMESTAMP_KEY = "timestampMillis"
        private const val WORLD_X_KEY = "worldX"
        private const val WORLD_Y_KEY = "worldY"
        private const val WORLD_Z_KEY = "worldZ"
        private const val GRAVITY_X_KEY = "gravityX"
        private const val GRAVITY_Y_KEY = "gravityY"
        private const val GRAVITY_Z_KEY = "gravityZ"
        private const val INTERFACE_ROTATION_DEG_KEY = "interfaceRotationDeg"
        private const val ACTIVE_PATH_POINTS_KEY = "activePathPoints"
        private const val FUTURE_PATH_POINTS_KEY = "futurePathPoints"
        private const val NEXT_WAYPOINT_KEY = "nextWaypoint"
        private const val DESTINATION_KEY = "destination"
    }
}

private class AndroidArPreviewFactory(
    private val bridge: AndroidArTrackingBridge,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return AndroidArPreviewPlatformView(context, bridge)
    }
}

private class AndroidArPreviewPlatformView(
    context: Context,
    private val bridge: AndroidArTrackingBridge,
) : PlatformView {
    private val container = FrameLayout(context)
    val renderer = ArSceneRenderer(bridge)
    private val surfaceView = GLSurfaceView(context)
    private val overlayView = ArOverlayView(context, bridge)

    init {
        surfaceView.setEGLContextClientVersion(2)
        surfaceView.preserveEGLContextOnPause = true
        surfaceView.holder.setFormat(PixelFormat.TRANSLUCENT)
        surfaceView.setRenderer(renderer)
        surfaceView.renderMode = GLSurfaceView.RENDERMODE_CONTINUOUSLY

        overlayView.setBackgroundColor(Color.TRANSPARENT)

        container.addView(
            surfaceView,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
            ),
        )
        container.addView(
            overlayView,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
            ),
        )

        bridge.registerPreviewView(this)
    }

    override fun getView(): View = container

    override fun dispose() {
        bridge.unregisterPreviewView(this)
        surfaceView.onPause()
    }

    fun onHostResume() {
        surfaceView.onResume()
    }

    fun onHostPause() {
        surfaceView.onPause()
    }

    fun requestOverlayRedraw() {
        overlayView.postInvalidateOnAnimation()
    }
}

private class ArSceneRenderer(
    private val bridge: AndroidArTrackingBridge,
) : GLSurfaceView.Renderer {
    @Volatile
    private var session: Session? = null

    @Volatile
    private var wantsCapture = false

    private val backgroundRenderer = ArCameraBackgroundRenderer()
    private var viewportWidth = 1
    private var viewportHeight = 1

    fun bindSession(session: Session) {
        this.session = session
        backgroundRenderer.bindSessionTexture(session)
    }

    fun onHostResume() {
    }

    fun requestFrameCapture() {
        wantsCapture = true
    }

    override fun onSurfaceCreated(gl: GL10?, config: EGLConfig?) {
        GLES20.glClearColor(0f, 0f, 0f, 1f)
        backgroundRenderer.createOnGlThread()
        session?.let { backgroundRenderer.bindSessionTexture(it) }
    }

    override fun onSurfaceChanged(gl: GL10?, width: Int, height: Int) {
        viewportWidth = width
        viewportHeight = height
        GLES20.glViewport(0, 0, width, height)
    }

    override fun onDrawFrame(gl: GL10?) {
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT or GLES20.GL_DEPTH_BUFFER_BIT)
        val localSession = session ?: return

        try {
            localSession.setDisplayGeometry(
                bridge.currentSurfaceRotation(),
                viewportWidth,
                viewportHeight,
            )
            val frame = localSession.update()
            backgroundRenderer.draw(frame)
            bridge.handleFrame(frame, viewportWidth, viewportHeight)
            if (wantsCapture) {
                wantsCapture = false
            }
        } catch (_: CameraNotAvailableException) {
        } catch (_: Exception) {
        }
    }
}

private class ArCameraBackgroundRenderer {
    private val quadVertices: FloatBuffer = allocateFloatBuffer(
        floatArrayOf(
            -1f, -1f,
            1f, -1f,
            -1f, 1f,
            1f, 1f,
        ),
    )
    private val quadTexCoords = FloatArray(8)
    private val quadTexCoordBuffer: FloatBuffer = allocateFloatBuffer(FloatArray(8))

    private var program = 0
    private var positionAttrib = 0
    private var texCoordAttrib = 0
    private var textureUniform = 0
    private var textureId = -1

    fun createOnGlThread() {
        textureId = createExternalTexture()
        program = createProgram(VERTEX_SHADER, FRAGMENT_SHADER)
        positionAttrib = GLES20.glGetAttribLocation(program, "a_Position")
        texCoordAttrib = GLES20.glGetAttribLocation(program, "a_TexCoord")
        textureUniform = GLES20.glGetUniformLocation(program, "sTexture")
    }

    fun bindSessionTexture(session: Session) {
        if (textureId != -1) {
            session.setCameraTextureNames(intArrayOf(textureId))
        }
    }

    fun draw(frame: Frame) {
        if (frame.timestamp == 0L || program == 0) {
            return
        }

        frame.transformCoordinates2d(
            Coordinates2d.OPENGL_NORMALIZED_DEVICE_COORDINATES,
            FULL_SCREEN_QUAD_COORDS,
            Coordinates2d.TEXTURE_NORMALIZED,
            quadTexCoords,
        )
        quadTexCoordBuffer.position(0)
        quadTexCoordBuffer.put(quadTexCoords)
        quadTexCoordBuffer.position(0)

        GLES20.glDisable(GLES20.GL_DEPTH_TEST)
        GLES20.glDepthMask(false)
        GLES20.glUseProgram(program)
        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, textureId)
        GLES20.glUniform1i(textureUniform, 0)

        quadVertices.position(0)
        GLES20.glVertexAttribPointer(positionAttrib, 2, GLES20.GL_FLOAT, false, 0, quadVertices)
        GLES20.glEnableVertexAttribArray(positionAttrib)

        GLES20.glVertexAttribPointer(texCoordAttrib, 2, GLES20.GL_FLOAT, false, 0, quadTexCoordBuffer)
        GLES20.glEnableVertexAttribArray(texCoordAttrib)

        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)

        GLES20.glDisableVertexAttribArray(positionAttrib)
        GLES20.glDisableVertexAttribArray(texCoordAttrib)
        GLES20.glDepthMask(true)
        GLES20.glEnable(GLES20.GL_DEPTH_TEST)
    }

    private fun createExternalTexture(): Int {
        val textures = IntArray(1)
        GLES20.glGenTextures(1, textures, 0)
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, textures[0])
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)
        return textures[0]
    }

    companion object {
        private val FULL_SCREEN_QUAD_COORDS = floatArrayOf(
            -1f, -1f,
            1f, -1f,
            -1f, 1f,
            1f, 1f,
        )

        private const val VERTEX_SHADER = """
            attribute vec4 a_Position;
            attribute vec2 a_TexCoord;
            varying vec2 v_TexCoord;
            void main() {
              gl_Position = a_Position;
              v_TexCoord = a_TexCoord;
            }
        """

        private const val FRAGMENT_SHADER = """
            #extension GL_OES_EGL_image_external : require
            precision mediump float;
            uniform samplerExternalOES sTexture;
            varying vec2 v_TexCoord;
            void main() {
              gl_FragColor = texture2D(sTexture, v_TexCoord);
            }
        """
    }
}

private class ArOverlayView(
    context: Context,
    private val bridge: AndroidArTrackingBridge,
) : View(context) {
    private val activePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#1AC7BE")
        strokeWidth = 12f
        style = Paint.Style.STROKE
        strokeCap = Paint.Cap.ROUND
        strokeJoin = Paint.Join.ROUND
        alpha = 245
    }
    private val futurePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#3B82F6")
        strokeWidth = 7f
        style = Paint.Style.STROKE
        strokeCap = Paint.Cap.ROUND
        strokeJoin = Paint.Join.ROUND
        alpha = 135
    }
    private val markerPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#1AC7BE")
        style = Paint.Style.FILL
        alpha = 235
    }
    private val destinationPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#F59E0B")
        style = Paint.Style.STROKE
        strokeWidth = 8f
        alpha = 235
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val matrix = bridge.currentViewProjectionMatrix() ?: return
        val snapshot = bridge.currentOverlaySnapshot()

        drawPath(canvas, snapshot.futurePathPoints, matrix, futurePaint)
        drawPath(canvas, snapshot.activePathPoints, matrix, activePaint)
        drawFlowMarker(canvas, snapshot.activePathPoints, matrix)
        snapshot.nextWaypoint?.let { drawMarker(canvas, it, matrix, 18f, markerPaint) }
        snapshot.destination?.let {
            drawMarker(canvas, it, matrix, 24f, markerPaint)
            drawMarker(canvas, it, matrix, 42f, destinationPaint)
        }
    }

    private fun drawPath(
        canvas: Canvas,
        points: List<Vector3>,
        matrix: FloatArray,
        paint: Paint,
    ) {
        if (points.size < 2) return
        for (index in 0 until points.lastIndex) {
            val start = project(points[index], matrix) ?: continue
            val end = project(points[index + 1], matrix) ?: continue
            canvas.drawLine(start.x, start.y, end.x, end.y, paint)
        }
    }

    private fun drawFlowMarker(canvas: Canvas, points: List<Vector3>, matrix: FloatArray) {
        if (points.size < 2) return
        val start = project(points[0], matrix) ?: return
        val end = project(points[1], matrix) ?: return
        val dx = end.x - start.x
        val dy = end.y - start.y
        val length = max(1f, kotlin.math.sqrt(dx * dx + dy * dy))
        val ux = dx / length
        val uy = dy / length
        val centerX = start.x + dx * 0.35f
        val centerY = start.y + dy * 0.35f

        val arrowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#1AC7BE")
            style = Paint.Style.FILL
            alpha = 245
        }
        val path = android.graphics.Path().apply {
            moveTo(centerX + ux * 28f, centerY + uy * 28f)
            lineTo(centerX - ux * 14f - uy * 12f, centerY - uy * 14f + ux * 12f)
            lineTo(centerX - ux * 14f + uy * 12f, centerY - uy * 14f - ux * 12f)
            close()
        }
        canvas.drawPath(path, arrowPaint)
    }

    private fun drawMarker(
        canvas: Canvas,
        point: Vector3,
        matrix: FloatArray,
        radius: Float,
        paint: Paint,
    ) {
        val screenPoint = project(point, matrix) ?: return
        canvas.drawCircle(screenPoint.x, screenPoint.y, radius, paint)
    }

    private fun project(point: Vector3, matrix: FloatArray): ScreenPoint? {
        val input = floatArrayOf(point.x, point.y, point.z, 1f)
        val clip = FloatArray(4)
        Matrix.multiplyMV(clip, 0, matrix, 0, input, 0)
        val w = clip[3]
        if (w <= 0.01f) return null

        val ndcX = clip[0] / w
        val ndcY = clip[1] / w
        val ndcZ = clip[2] / w
        if (ndcZ < -1f || ndcZ > 1f) return null

        val screenX = (ndcX * 0.5f + 0.5f) * width
        val screenY = (1f - (ndcY * 0.5f + 0.5f)) * height
        if (screenX < -width || screenX > width * 2 || screenY < -height || screenY > height * 2) {
            return null
        }
        return ScreenPoint(screenX, screenY)
    }
}

private data class OverlaySnapshot(
    val activePathPoints: List<Vector3> = emptyList(),
    val futurePathPoints: List<Vector3> = emptyList(),
    val nextWaypoint: Vector3? = null,
    val destination: Vector3? = null,
)

private data class Vector3(val x: Float, val y: Float, val z: Float)

private data class ScreenPoint(val x: Float, val y: Float)

private data class FlutterErrorPayload(
    val code: String,
    val message: String,
)

private fun allocateFloatBuffer(values: FloatArray): FloatBuffer {
    val buffer = ByteBuffer
        .allocateDirect(values.size * 4)
        .order(ByteOrder.nativeOrder())
        .asFloatBuffer()
    buffer.put(values)
    buffer.position(0)
    return buffer
}

private fun loadShader(type: Int, source: String): Int {
    val shader = GLES20.glCreateShader(type)
    GLES20.glShaderSource(shader, source)
    GLES20.glCompileShader(shader)
    return shader
}

private fun createProgram(vertexShaderSource: String, fragmentShaderSource: String): Int {
    val vertexShader = loadShader(GLES20.GL_VERTEX_SHADER, vertexShaderSource)
    val fragmentShader = loadShader(GLES20.GL_FRAGMENT_SHADER, fragmentShaderSource)
    val program = GLES20.glCreateProgram()
    GLES20.glAttachShader(program, vertexShader)
    GLES20.glAttachShader(program, fragmentShader)
    GLES20.glLinkProgram(program)
    GLES20.glDeleteShader(vertexShader)
    GLES20.glDeleteShader(fragmentShader)
    return program
}
