using System;
using UnityEngine;

[Serializable]
public class AvatarLoadMessage
{
    public string avatarUrl;
    public string userId;
}

public class FlutterBridge : MonoBehaviour
{
    [SerializeField]
    private AvatarSceneManager avatarSceneManager;

    public void LoadAvatarFromFlutter(string messageJson)
    {
        if (avatarSceneManager == null)
        {
            Debug.LogError("AvatarSceneManager reference is not set in FlutterBridge.");
            return;
        }
        if (string.IsNullOrWhiteSpace(messageJson))
        {
            Debug.LogError("Received empty message from Flutter.");
            return;
        }

        AvatarLoadMessage message;
        try
        {
            message = JsonUtility.FromJson<AvatarLoadMessage>(messageJson);
        }
        catch (Exception ex)
        {
            Debug.LogErrorFormat("Failed to parse AvatarLoadMessage from JSON: {0}", ex.Message);
            return;
        }

        if (message == null || string.IsNullOrWhiteSpace(message.avatarUrl))
        {
            Debug.LogError("Invalid AvatarLoadMessage received from Flutter.");
            return;
        }

        avatarSceneManager.LoadAvatar(message.avatarUrl);
    }
}
