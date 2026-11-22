package miui.process;
import android.os.Parcel;
import android.os.Parcelable;
public class ForegroundInfo implements Parcelable {
    public static final int FLAG_FOREGROUND_COLD_START = 1;
    public int mFlags;
    public int mForegroundDisplayId;
    public int mForegroundPid;
    public int mForegroundUid;
    public int mLastForegroundDisplayId;
    public int mLastForegroundPid;
    public int mLastForegroundUid;
    public int mMultiWindowForegroundUid;
    public String mForegroundPackageName;
    public String mLastForegroundPackageName;
    public String mMultiWindowForegroundPackageName;
    public ForegroundInfo(){}
    public ForegroundInfo(Parcel in){
        mFlags = in.readInt();
        mForegroundDisplayId = in.readInt();
        mForegroundPid = in.readInt();
        mForegroundPackageName = in.readString();
        mForegroundUid = in.readInt();
        mLastForegroundDisplayId = in.readInt();
        mLastForegroundPid = in.readInt();
        mLastForegroundPackageName = in.readString();
        mLastForegroundUid = in.readInt();
        mMultiWindowForegroundPackageName = in.readString();
        mMultiWindowForegroundUid = in.readInt();
    }
    public ForegroundInfo(ForegroundInfo o){
        mFlags=o.mFlags; mForegroundDisplayId=o.mForegroundDisplayId; mForegroundPid=o.mForegroundPid;
        mForegroundUid=o.mForegroundUid; mLastForegroundDisplayId=o.mLastForegroundDisplayId;
        mLastForegroundPid=o.mLastForegroundPid; mLastForegroundUid=o.mLastForegroundUid;
        mMultiWindowForegroundUid=o.mMultiWindowForegroundUid; mForegroundPackageName=o.mForegroundPackageName;
        mLastForegroundPackageName=o.mLastForegroundPackageName; mMultiWindowForegroundPackageName=o.mMultiWindowForegroundPackageName;
    }
    public void addFlags(int f){ mFlags |= f; }
    public void resetFlags(){ mFlags = 0; }
    public boolean isColdStart(){ return (mFlags & FLAG_FOREGROUND_COLD_START) != 0; }
    public int describeContents(){ return 0; }
    public void writeToParcel(Parcel d, int flags){
        d.writeInt(mFlags); d.writeInt(mForegroundDisplayId); d.writeInt(mForegroundPid);
        d.writeString(mForegroundPackageName); d.writeInt(mForegroundUid);
        d.writeInt(mLastForegroundDisplayId); d.writeInt(mLastForegroundPid);
        d.writeString(mLastForegroundPackageName); d.writeInt(mLastForegroundUid);
        d.writeString(mMultiWindowForegroundPackageName); d.writeInt(mMultiWindowForegroundUid);
    }
    public static final Parcelable.Creator<ForegroundInfo> CREATOR = new Parcelable.Creator<ForegroundInfo>(){
        public ForegroundInfo createFromParcel(Parcel in){ return new ForegroundInfo(in); }
        public ForegroundInfo[] newArray(int n){ return new ForegroundInfo[n]; }
    };
}
