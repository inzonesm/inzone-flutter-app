using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class WorldManager : MonoBehaviour
{
    [Header("World References")]
    public GameObject[] worlds;

    [Header("Space Skybox")]
    public Material customSkybox;
    public int customSkyboxWorldIndex = 2;

    private Material defaultSkybox;
    private int currentWorldIndex = 2;

    void Start()
    {
        defaultSkybox = RenderSettings.skybox;
        SwitchWorld(2);
    }

    public void SwitchWorld(int newWorldIndex)
    {
        if (newWorldIndex < 0 || newWorldIndex >= worlds.Length)
        {
            Debug.LogWarning("Invalid world index.");
            return;
        }

        // turn all worlds off except active one
        for (int i = 0; i < worlds.Length; i++)
        {
            worlds[i].SetActive(i == newWorldIndex);
        }

        // change skybox
        if (newWorldIndex == customSkyboxWorldIndex)
        {
            RenderSettings.skybox = customSkybox;
        }
        else
        {
            RenderSettings.skybox = defaultSkybox;
        }

        DynamicGI.UpdateEnvironment();
        currentWorldIndex = newWorldIndex;
    }
}
