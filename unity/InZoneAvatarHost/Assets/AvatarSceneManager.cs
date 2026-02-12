using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using UnityEngine;
using GLTFast;

[System.Serializable]
public class WorldCameraPreset
{
    public string worldId;
    public Vector3 avatarLocalPos;
    public Vector3 cameraPosition;
}

public class AvatarSceneManager : MonoBehaviour
{
    [Serializable]
    public class WorldEntry
    {
        public string worldId;
        public string glbPathOrUrl;
    }

    public Camera mainCamera;

    [Header("Camera framing")]
    public Vector3 cameraEulerAngles = new Vector3(30f, 15f, 0f);
    public float cameraFov = 60f;

    public List<WorldCameraPreset> worldCameraPresets = new List<WorldCameraPreset>();

    private Dictionary<string, Vector3> cameraPresetMap;
    private Dictionary<string, Vector3> avatarPresetMap;

    [Header("World Loading")]
    public Transform worldRoot;
    public List<WorldEntry> worldEntries;

    [Header("Optional")]
    public string avatarAnchorName = "AvatarAnchor";

    // Keep a map so we can switch worlds easily by ID
    private Dictionary<string, string> worlds;
    private Transform currentAvatarAnchor;
    private GameObject loadedWorldInstance;
    private string loadedWorldId;

    private GameObject currentAvatarInstance;

    private void Awake()
    {
        worlds = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        foreach (var e in worldEntries)
        {
            if (!string.IsNullOrWhiteSpace(e.worldId) && !string.IsNullOrWhiteSpace(e.glbPathOrUrl))
            {
                worlds[e.worldId] = e.glbPathOrUrl;
            }
        }

        cameraPresetMap = new Dictionary<string, Vector3>(StringComparer.OrdinalIgnoreCase);
        avatarPresetMap = new Dictionary<string, Vector3>(StringComparer.OrdinalIgnoreCase);
        foreach (var p in worldCameraPresets)
        {
            if (!string.IsNullOrWhiteSpace(p.worldId))
            {
                cameraPresetMap[p.worldId] = p.cameraPosition;
                avatarPresetMap[p.worldId] = p.avatarLocalPos;
            }
        }
    }

    private void Start()
    {
        if (worlds == null || worlds.Count == 0)
        {
            Debug.LogError("No worlds configured in AvatarSceneManager.worldEntries.");
            return;
        }

        // pick a random world entry from the dictionary
        var entries = new List<KeyValuePair<string, string>>(worlds);
        var selected = entries[UnityEngine.Random.Range(0, entries.Count)];

        loadedWorldId = selected.Key;
        ApplyCameraForWorld(loadedWorldId);
        var worldGlbPathOrUrl = selected.Value;

        StartCoroutine(LoadWorldRoutine(worldGlbPathOrUrl));
    }

    private IEnumerator LoadWorldRoutine(string worldGlbPathOrUrl)
    {
        var gltf = new GltfImport();
        string worldUrl = worldGlbPathOrUrl;

        if (!worldGlbPathOrUrl.StartsWith("http", StringComparison.OrdinalIgnoreCase) &&
            !worldGlbPathOrUrl.StartsWith("file:", StringComparison.OrdinalIgnoreCase))
        {
            worldUrl = Path.Combine(Application.streamingAssetsPath, worldGlbPathOrUrl);
        }

        var loadTask = gltf.Load(worldUrl);
        while (!loadTask.IsCompleted)
        {
            yield return null;
        }
        if (!loadTask.Result)
        {
            Debug.LogError($"Failed to load world GLB from: {worldUrl}");
            yield break;
        }

        loadedWorldInstance = new GameObject("LoadedWorld");
        var instTask = gltf.InstantiateMainSceneAsync(loadedWorldInstance.transform);
        while (!instTask.IsCompleted)
        {
            yield return null;
        }

        var anchorGO = new GameObject("AvatarAnchor");
        anchorGO.transform.SetParent(loadedWorldInstance.transform, false);
        anchorGO.transform.localPosition = Vector3.zero;

        currentAvatarAnchor = anchorGO.transform;
    }

    // Call this from Flutter -> Unity bridge
    public void LoadAvatar(string avatarGlbUrl)
    {
        StartCoroutine(LoadAvatarRoutine(avatarGlbUrl));
    }

    public IEnumerator LoadAvatarRoutine(string avatarGlbUrl)
    {
        if (currentAvatarInstance != null)
        {
            Destroy(currentAvatarInstance);
            currentAvatarInstance = null;
        }

        var gltf = new GltfImport();
        var loadTask = gltf.Load(avatarGlbUrl);
        while (!loadTask.IsCompleted)
        {
            yield return null;
        }

        if (!loadTask.Result)
        {
            Debug.LogError($"Failed to load avatar GLB from: {avatarGlbUrl}");
            yield break;
        }

        currentAvatarInstance = new GameObject("AvatarInstance");
        currentAvatarInstance.transform.SetParent(currentAvatarAnchor, false);

        var instTask = gltf.InstantiateMainSceneAsync(currentAvatarInstance.transform);
        while (!instTask.IsCompleted)
        {
            yield return null;
        }

        currentAvatarInstance.transform.localRotation = Quaternion.Euler(0f, 180f, 0f);
        if (avatarPresetMap.TryGetValue(loadedWorldId, out var avatarPos))
        {
            if (currentAvatarInstance != null)
            {
                currentAvatarInstance.transform.localPosition = avatarPos;
                if (loadedWorldId == "creative_studio")
                {
                    currentAvatarInstance.transform.localScale = Vector3.one * 0.7f;
                }
            }
        }
        else
        {
            Debug.LogWarning($"No avatar preset found for worldId: {loadedWorldId}");
        }
    }

    private Transform FindOrCreateAvatarAnchor(GameObject world)
    {
        var anchor = world.transform.Find("AvatarAnchor");
        if (anchor != null) return anchor;

        var anchorGO = new GameObject("AvatarAnchor");
        anchorGO.transform.SetParent(world.transform, false);
        anchorGO.transform.localPosition = Vector3.zero;
        anchorGO.transform.localRotation = Quaternion.identity;
        anchorGO.transform.localScale = Vector3.one;

        return anchorGO.transform;
    }

    private Transform FindRecursive(Transform root, string name)
    {
        if (root.name == name) return root;
        for (int i = 0; i < root.childCount; i++)
        {
            var found = FindRecursive(root.GetChild(i), name);
            if (found != null) return found;
        }
        return null;
    }

    private void ClearCurrentAvatar()
    {
        if (currentAvatarInstance != null)
        {
            Destroy(currentAvatarInstance);
            currentAvatarInstance = null;
        }
    }

    private void ApplyCameraForWorld(string worldId)
    {
        if (mainCamera == null) mainCamera = Camera.main;
        if (mainCamera == null) return;

        mainCamera.fieldOfView = cameraFov;
        mainCamera.transform.rotation = Quaternion.Euler(cameraEulerAngles);

        if (cameraPresetMap.TryGetValue(worldId, out var pos))
        {
            mainCamera.transform.position = pos;
        }
        else
        {
            Debug.LogWarning($"No camera preset found for worldId: {worldId}");
        }
    }
}
