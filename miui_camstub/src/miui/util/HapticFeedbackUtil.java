package miui.util;
import android.content.Context;
import android.os.VibrationAttributes;
public class HapticFeedbackUtil {
    public HapticFeedbackUtil(Context c, boolean z){}
    public static boolean isSupportLinearMotorVibrate(){ return false; }
    public static boolean isSupportLinearMotorVibrate(int i){ return false; }
    public boolean performExtHapticFeedback(int i){ return false; }
    public boolean performHapticFeedback(int i, double d, String s){ return false; }
    public boolean performHapticFeedback(int i, boolean b){ return false; }
    public boolean performHapticFeedback(int i, boolean b, int j){ return false; }
    public boolean performHapticFeedback(VibrationAttributes a, int i, boolean b){ return false; }
    public boolean performHapticFeedback(VibrationAttributes a, int i, boolean b, int j){ return false; }
    public boolean performHapticFeedback(VibrationAttributes a, int i, double d, String s){ return false; }
}
