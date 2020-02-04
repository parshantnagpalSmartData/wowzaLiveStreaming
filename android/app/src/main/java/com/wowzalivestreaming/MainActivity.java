package com.wowzalivestreaming;
import android.Manifest;
import androidx.core.app.ActivityCompat;
import com.facebook.react.ReactActivity;
import androidx.appcompat.app.AppCompatActivity;
import android.content.pm.PackageManager;

public class MainActivity extends ReactActivity {

  @Override
  public void onResume() {
    super.onResume();
    if (!hasPermission(Manifest.permission.CAMERA)
            && !hasPermission(Manifest.permission.RECORD_AUDIO))
      ActivityCompat.requestPermissions(this, new String[] {Manifest.permission.CAMERA,
              Manifest.permission.RECORD_AUDIO}, 1);
    else if (!hasPermission(Manifest.permission.RECORD_AUDIO))
      ActivityCompat.requestPermissions(this, new String[] {Manifest.permission.RECORD_AUDIO}, 1);
    else if (!hasPermission(Manifest.permission.CAMERA))
      ActivityCompat.requestPermissions(this, new String[] {Manifest.permission.CAMERA}, 1);
  }

  private boolean hasPermission(String permission) {
    return ActivityCompat.checkSelfPermission(this, permission) == PackageManager.PERMISSION_GRANTED;
  }
  /**
   * Returns the name of the main component registered from JavaScript. This is used to schedule
   * rendering of the component.
   */
  @Override

  protected String getMainComponentName() {
    return "WowzaLiveStreaming";
  }
}
