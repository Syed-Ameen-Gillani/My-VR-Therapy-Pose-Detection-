# Room creates WorkManager's generated database by reflection. The older Room
# consumer rule keeps its class name but R8 can still remove its constructor.
# ML Kit pose acceleration requires WorkManager, including in release builds.
-keep class androidx.work.impl.WorkDatabase_Impl {
    public <init>();
}

# ML Kit discovers these registrars by manifest class name and reflection.
-keep class com.google.mlkit.** implements com.google.firebase.components.ComponentRegistrar {
    public <init>();
}
