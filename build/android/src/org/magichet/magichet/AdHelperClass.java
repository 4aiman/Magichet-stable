package org.magichet.magichet;

import android.app.Activity;

import com.apptracker.android.listener.AppModuleListener;
import com.apptracker.android.track.AppTracker;
import com.purplebrain.adbuddiz.sdk.AdBuddiz;

public class AdHelperClass {
	private static final String APP_API_KEY = "j0jyGGKqZVspFASepHhFsWOYt5ZB3WSN";
	private static final String LOCATION_CODE = "inapp";

	private Activity mActivity;

	public AdHelperClass(Activity activity) {
		mActivity = activity;
		adActivityInit();
	}

	private void adActivityInit() {
		// Initialize Leadbolt
		AppTracker.startSession(mActivity.getApplicationContext(),
				APP_API_KEY);
		AppTracker.setModuleListener(new AppModuleListener() {
			@Override
			public void onModuleLoaded(String placement) {
			}

			@Override
			public void onModuleFailed(String placement, String error,
					boolean isCache) {
				if (!isCache) {
					showAdBuddiz();
				}
			}

			@Override
			public void onModuleClosed(String placement) {
				// once Ad is closed cache the next Ad
				AppTracker.loadModuleToCache(mActivity.getApplicationContext(),
						LOCATION_CODE);
			}

			@Override
			public void onModuleClicked(String placement) {
			}

			@Override
			public void onModuleCached(String placement) {
			}

			@Override
			public void onMediaFinished(boolean arg0) {
				// TODO Auto-generated method stub
				
			}
		});
		AppTracker.loadModuleToCache(mActivity.getApplicationContext(),
				LOCATION_CODE);

		// AdBuddiz
		AdBuddiz.setPublisherKey("db49c44a-5f90-4173-b3c0-ad4f01e157bb");
		AdBuddiz.cacheAds(mActivity);
	}

	// Main public method to display Ads
	public void showAd() {
		showLeadbolt();
	}

	// Internal methods to show individual Ad networks
	public void showAdBuddiz() {
		AdBuddiz.showAd(mActivity);
	}

	private void showLeadbolt() {
		AppTracker.loadModule(mActivity.getApplicationContext(), LOCATION_CODE);
	}

}
