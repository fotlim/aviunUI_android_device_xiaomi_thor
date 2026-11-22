package miui.hardware.display;
public class DisplayFeatureManager {
    private static final DisplayFeatureManager sInstance = new DisplayFeatureManager();
    public static final int SCREEN_NIGHTLIGHT = 1;
    public static final int SCREEN_STANDARD = 2;
    public static final int SCREEN_ENHANCE = 3;
    public static final int HDR_STATE = 4;
    public static DisplayFeatureManager getInstance(){ return sInstance; }
    public void setScreenEffect(int mode, int value){}
    public void setScreenEffect(int mode, int value, int extra){}
}
