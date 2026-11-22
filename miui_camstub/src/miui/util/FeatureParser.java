package miui.util;
public class FeatureParser {
    public static boolean hasFeature(String name){ return false; }
    public static boolean hasFeature(String name, int def){ return false; }
    public static int getInt(String key, int def){ return def; }
    public static long getLong(String key, long def){ return def; }
    public static String getString(String key){ return null; }
    public static boolean getBoolean(String key, boolean def){ return def; }
}
