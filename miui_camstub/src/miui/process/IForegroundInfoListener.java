package miui.process;
import android.os.IBinder;
import android.os.IInterface;
import android.os.Binder;
import android.os.Parcel;
import android.os.RemoteException;
public interface IForegroundInfoListener extends IInterface {
    void onForegroundInfoChanged(ForegroundInfo info) throws RemoteException;
    public static abstract class Stub extends Binder implements IForegroundInfoListener {
        private static final String DESCRIPTOR = "miui.process.IForegroundInfoListener";
        public Stub(){ attachInterface(this, DESCRIPTOR); }
        public static IForegroundInfoListener asInterface(IBinder obj){
            if (obj == null) return null;
            IInterface iin = obj.queryLocalInterface(DESCRIPTOR);
            if (iin != null && iin instanceof IForegroundInfoListener) return (IForegroundInfoListener) iin;
            return new Proxy(obj);
        }
        public static IForegroundInfoListener getDefaultImpl(){ return null; }
        public IBinder asBinder(){ return this; }
        public boolean onTransact(int code, Parcel data, Parcel reply, int flags) throws RemoteException {
            if (code == 1){
                data.enforceInterface(DESCRIPTOR);
                ForegroundInfo _arg0 = data.readInt() != 0 ? ForegroundInfo.CREATOR.createFromParcel(data) : null;
                onForegroundInfoChanged(_arg0);
                return true;
            }
            return super.onTransact(code, data, reply, flags);
        }
        public static class Proxy implements IForegroundInfoListener {
            private IBinder mRemote;
            public Proxy(IBinder remote){ this.mRemote = remote; }
            public IBinder asBinder(){ return mRemote; }
            public void onForegroundInfoChanged(ForegroundInfo info) throws RemoteException {
                Parcel _data = Parcel.obtain();
                try {
                    _data.writeInterfaceToken(DESCRIPTOR);
                    if (info != null){ _data.writeInt(1); info.writeToParcel(_data, 0); } else { _data.writeInt(0); }
                    mRemote.transact(1, _data, null, android.os.IBinder.FLAG_ONEWAY);
                } finally { _data.recycle(); }
            }
        }
    }
}
