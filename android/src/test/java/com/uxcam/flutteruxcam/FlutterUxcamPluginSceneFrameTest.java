package com.uxcam.flutteruxcam;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;

import com.uxcam.screenshot.screenshotTaker.SceneFrameResponse;

import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * The plugin is a transport, so these tests are about faithfully carrying a payload across — and in
 * particular about the one judgement it does make: which unit system the rects are in.
 */
@RunWith(RobolectricTestRunner.class)
public class FlutterUxcamPluginSceneFrameTest {

    private Map<String, Object> rect(String k1, Object v1, String k2, Object v2,
                                     String k3, Object v3, String k4, Object v4) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put(k1, v1); m.put(k2, v2); m.put(k3, v3); m.put(k4, v4);
        return m;
    }

    private Map<String, Object> payload(List<Object> rects) {
        Map<String, Object> m = new HashMap<>();
        m.put("rects", rects);
        m.put("coordinateSpace", "sourceLogicalPoints");
        m.put("referenceWidth", 360.0);
        m.put("referenceHeight", 640.0);
        m.put("logicalWidth", 360.0);
        m.put("logicalHeight", 640.0);
        return m;
    }

    /**
     * Android's Dart encoder emits left/top/right/bottom in device pixels while the same response
     * declares coordinateSpace "sourceLogicalPoints". The key shape is the reliable signal; trusting
     * the string would misplace every mask by the device pixel ratio.
     */
    @Test
    public void edgeKeyedRectsAreReadAsDevicePixelsDespiteTheCoordinateSpaceString() {
        List<Object> rects = new ArrayList<>();
        rects.add(rect("left", 10.0, "top", 20.0, "right", 30.0, "bottom", 40.0));

        SceneFrameResponse response = FlutterUxcamPlugin.parseSceneFrameResponse(payload(rects));

        assertEquals(SceneFrameResponse.UNITS_DEVICE_PIXELS, response.rectUnits);
        assertEquals(1, response.rects.size());
        assertEquals(10f, response.rects.get(0).left, 0.001f);
        assertEquals(40f, response.rects.get(0).bottom, 0.001f);
        assertTrue(response.hasValidOcclusionMetadata());
    }

    @Test
    public void cornerKeyedRectsAreReadAsLogicalPoints() {
        List<Object> rects = new ArrayList<>();
        rects.add(rect("x0", 1.0, "y0", 2.0, "x1", 3.0, "y1", 4.0));

        SceneFrameResponse response = FlutterUxcamPlugin.parseSceneFrameResponse(payload(rects));

        assertEquals(SceneFrameResponse.UNITS_LOGICAL_POINTS, response.rectUnits);
        assertEquals(1f, response.rects.get(0).left, 0.001f);
        assertEquals(4f, response.rects.get(0).bottom, 0.001f);
    }

    @Test
    public void aUint8ListArrivesAsAByteArrayAndIsCarriedThrough() {
        Map<String, Object> map = payload(new ArrayList<>());
        map.put("bytes", new byte[2 * 2 * 4]);
        map.put("pixelWidth", 2);
        map.put("pixelHeight", 2);

        SceneFrameResponse response = FlutterUxcamPlugin.parseSceneFrameResponse(map);

        assertTrue(response.hasPixels());
        assertEquals(16, response.rgbaBytes.length);
        assertEquals(2, response.pixelWidth);
    }

    /** Geometry with no raster is a normal answer, not a failure — native capture fills in. */
    @Test
    public void geometryWithoutARasterIsValidAndCarriesNoPixels() {
        List<Object> rects = new ArrayList<>();
        rects.add(rect("left", 0.0, "top", 0.0, "right", 5.0, "bottom", 5.0));

        SceneFrameResponse response = FlutterUxcamPlugin.parseSceneFrameResponse(payload(rects));

        assertFalse(response.hasPixels());
        assertTrue(response.hasValidOcclusionMetadata());
        assertEquals(1, response.rects.size());
    }

    /** A half-populated pixel set is not usable, but it says nothing about the geometry. */
    @Test
    public void missingPixelDimensionsDropThePixelsWithoutCondemningTheGeometry() {
        Map<String, Object> map = payload(new ArrayList<>());
        map.put("bytes", new byte[16]);
        // pixelWidth/pixelHeight deliberately absent

        SceneFrameResponse response = FlutterUxcamPlugin.parseSceneFrameResponse(map);

        assertFalse(response.hasPixels());
        assertTrue(response.hasValidOcclusionMetadata());
    }

    /**
     * Mirrors iOS: bad geometry marks the metadata so the SDK can cover the frame, but it must not
     * throw away a raster that was perfectly good.
     */
    @Test
    public void malformedGeometryIsMarkedWithoutDiscardingTheRaster() {
        List<Object> rects = new ArrayList<>();
        rects.add(rect("left", 0.0, "top", 0.0, "right", 5.0, "bottom", 5.0));
        rects.add("not a rect");
        Map<String, Object> map = payload(rects);
        map.put("bytes", new byte[16]);
        map.put("pixelWidth", 2);
        map.put("pixelHeight", 2);

        SceneFrameResponse response = FlutterUxcamPlugin.parseSceneFrameResponse(map);

        assertFalse(response.hasValidOcclusionMetadata());
        assertTrue(response.rects.isEmpty());
        assertTrue(response.hasPixels());
    }

    @Test
    public void anInvertedRectMarksTheBatchMalformed() {
        List<Object> rects = new ArrayList<>();
        rects.add(rect("left", 50.0, "top", 0.0, "right", 10.0, "bottom", 5.0));

        SceneFrameResponse response = FlutterUxcamPlugin.parseSceneFrameResponse(payload(rects));

        assertFalse(response.hasValidOcclusionMetadata());
    }

    @Test
    public void aRectMissingAnEdgeMarksTheBatchMalformed() {
        Map<String, Object> partial = new LinkedHashMap<>();
        partial.put("left", 0.0);
        partial.put("top", 0.0);
        partial.put("right", 5.0);

        SceneFrameResponse response =
                FlutterUxcamPlugin.parseSceneFrameResponse(payload(new ArrayList<>(Arrays.asList((Object) partial))));

        assertFalse(response.hasValidOcclusionMetadata());
    }

    @Test
    public void aRectsFieldOfTheWrongTypeMarksTheBatchMalformed() {
        Map<String, Object> map = payload(new ArrayList<>());
        map.put("rects", "not a list");

        SceneFrameResponse response = FlutterUxcamPlugin.parseSceneFrameResponse(map);

        assertFalse(response.hasValidOcclusionMetadata());
    }

    @Test
    public void anEmptyGeometryListIsValidAndNotMalformed() {
        SceneFrameResponse response = FlutterUxcamPlugin.parseSceneFrameResponse(payload(new ArrayList<>()));

        assertTrue(response.hasValidOcclusionMetadata());
        assertTrue(response.rects.isEmpty());
    }

    /** null tells the SDK the response was unparseable, which is distinct from malformed geometry. */
    @Test
    public void aNonMapResponseIsRejectedOutright() {
        assertNull(FlutterUxcamPlugin.parseSceneFrameResponse("nonsense"));
        assertNull(FlutterUxcamPlugin.parseSceneFrameResponse(null));
    }

    @Test
    public void integerCoordinatesAreAcceptedAlongsideDoubles() {
        List<Object> rects = new ArrayList<>();
        rects.add(rect("x0", 1, "y0", 2, "x1", 3, "y1", 4));

        SceneFrameResponse response = FlutterUxcamPlugin.parseSceneFrameResponse(payload(rects));

        assertTrue(response.hasValidOcclusionMetadata());
        assertEquals(3f, response.rects.get(0).right, 0.001f);
    }
}
