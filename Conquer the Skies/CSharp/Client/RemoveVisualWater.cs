using System;
using System.Reflection;
using System.Collections.Generic;
using System.Linq;
using FarseerPhysics;
using Barotrauma;
using Barotrauma.Extensions;
using Barotrauma.Particles;
using HarmonyLib;
using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;

namespace NoWater
{
	class NoWaterModCS : IAssemblyPlugin
	{
		public Harmony harmony;
		
		public void Initialize()
		{
			harmony = new Harmony("no.water");
			
			harmony.Patch(
			original: typeof(WaterRenderer).GetMethod("RenderWater"),
			prefix: new HarmonyMethod(typeof(NoWaterModCS).GetMethod("OverrideRenderWater"))
			);
			harmony.Patch(
			original: typeof(CharacterHealth).GetMethod("UpdateStatusHUD"),
			prefix: new HarmonyMethod(typeof(NoWaterModCS).GetMethod("OverrideUpdateStatusHUD"))
			);
            // new patches
			harmony.Patch(
			original: typeof(Particle).GetMethod("Draw"),
			prefix: new HarmonyMethod(typeof(NoWaterModCS).GetMethod("OverrideParticleDraw"))
			);
		}
		
		public void OnLoadCompleted() { }
		public void PreInitPatching() { }

		public void Dispose()
		{
			harmony.UnpatchSelf();
			harmony = null;
			//reverse changes in water render
			WaterRenderer.Instance.WaterEffect.Parameters["waterColor"].SetValue(new Color(0.75f * 0.5f, 0.8f * 0.5f, 0.9f * 0.5f, 1.0f).ToVector4());
			WaterRenderer.DistortionScale = new Vector2(2f, 1.5f);
			WaterRenderer.DistortionStrength = new Vector2(0.01f, 0.33f);
		}
		
		public static bool OverrideRenderWater(SpriteBatch spriteBatch, RenderTarget2D texture, Camera cam, WaterRenderer __instance)
        {
            spriteBatch.GraphicsDevice.BlendState = BlendState.NonPremultiplied;

            __instance.WaterEffect.Parameters["xTexture"].SetValue(texture);
			//changes in water render when outside
			__instance.WaterEffect.Parameters["waterColor"].SetValue(new Color(1f, 1f, 1f, 1f).ToVector4());
            __instance.WaterEffect.Parameters["xWaveWidth"].SetValue(0f);
            __instance.WaterEffect.Parameters["xWaveHeight"].SetValue(0f);
			//outside draw call or smt
			__instance.WaterEffect.CurrentTechnique.Passes[0].Apply();
			//reverse changes in water render
			//__instance.WaterEffect.Parameters["waterColor"].SetValue(new Color(0.75f * 0.5f, 0.8f * 0.5f, 0.9f * 0.5f, 1.0f).ToVector4());
			__instance.WaterEffect.Parameters["waterColor"].SetValue(new Color(50f / 255f, 150f / 255f, 200f / 255f, 1.0f).ToVector4());
			
            Vector2 distortionStrength = cam == null ? WaterRenderer.DistortionStrength : WaterRenderer.DistortionStrength * cam.Zoom;
            __instance.WaterEffect.Parameters["xWaveWidth"].SetValue(WaterRenderer.DistortionStrength.X);
            __instance.WaterEffect.Parameters["xWaveHeight"].SetValue(WaterRenderer.DistortionStrength.Y);
            if (WaterRenderer.BlurAmount > 0.0f)
            {
                __instance.WaterEffect.CurrentTechnique = __instance.WaterEffect.Techniques["WaterShaderBlurred"];
                __instance.WaterEffect.Parameters["xBlurDistance"].SetValue(WaterRenderer.BlurAmount / 100.0f);
            }
            else
            {
                __instance.WaterEffect.CurrentTechnique = __instance.WaterEffect.Techniques["WaterShader"];
            }

            Vector2 offset = __instance.WavePos;
            if (cam != null)
            {
                offset += (cam.Position - new Vector2(cam.WorldView.Width / 2.0f, -cam.WorldView.Height / 2.0f));
                offset.Y += cam.WorldView.Height;
                offset.X += cam.WorldView.Width;
#if LINUX || OSX
                offset.X += cam.WorldView.Width;
#endif
                offset *= WaterRenderer.DistortionScale;
            }
            offset.Y = -offset.Y;
            __instance.WaterEffect.Parameters["xUvOffset"].SetValue(new Vector2((offset.X / GameMain.GraphicsWidth) % 1.0f, (offset.Y / GameMain.GraphicsHeight) % 1.0f));
            __instance.WaterEffect.Parameters["xBumpPos"].SetValue(Vector2.Zero);

            if (cam != null)
            {
                __instance.WaterEffect.Parameters["xBumpScale"].SetValue(new Vector2(
                        (float)cam.WorldView.Width / GameMain.GraphicsWidth * WaterRenderer.DistortionScale.X,
                        (float)cam.WorldView.Height / GameMain.GraphicsHeight * WaterRenderer.DistortionScale.Y));
                __instance.WaterEffect.Parameters["xTransform"].SetValue(cam.ShaderTransform
                    * Matrix.CreateOrthographic(GameMain.GraphicsWidth, GameMain.GraphicsHeight, -1, 1) * 0.5f);
                __instance.WaterEffect.Parameters["xUvTransform"].SetValue(cam.ShaderTransform
                    * Matrix.CreateOrthographicOffCenter(0, spriteBatch.GraphicsDevice.Viewport.Width * 2, spriteBatch.GraphicsDevice.Viewport.Height * 2, 0, 0, 1) * Matrix.CreateTranslation(0.5f, 0.5f, 0.0f));
            }
            else
            {
                __instance.WaterEffect.Parameters["xBumpScale"].SetValue(new Vector2(1.0f, 1.0f));
                __instance.WaterEffect.Parameters["xTransform"].SetValue(Matrix.Identity * Matrix.CreateTranslation(-1.0f, 1.0f, 0.0f));
                __instance.WaterEffect.Parameters["xUvTransform"].SetValue(Matrix.CreateScale(0.5f, -0.5f, 0.0f));
            }
			
			//original outside water draw
            //__instance.WaterEffect.CurrentTechnique.Passes[0].Apply();

            Rectangle view = cam != null ? cam.WorldView : spriteBatch.GraphicsDevice.Viewport.Bounds;

            __instance.tempCorners[0] = new Vector3(view.X, view.Y, 0.1f);
            __instance.tempCorners[1] = new Vector3(view.Right, view.Y, 0.1f);
            __instance.tempCorners[2] = new Vector3(view.Right, view.Y - view.Height, 0.1f);
            __instance.tempCorners[3] = new Vector3(view.X, view.Y - view.Height, 0.1f);

            WaterVertexData backGroundColor = new WaterVertexData(0.1f, 0.1f, 0.5f, 1.0f);
            __instance.tempVertices[0] = new VertexPositionColorTexture(__instance.tempCorners[0], backGroundColor, Vector2.Zero);
            __instance.tempVertices[1] = new VertexPositionColorTexture(__instance.tempCorners[1], backGroundColor, Vector2.Zero);
            __instance.tempVertices[2] = new VertexPositionColorTexture(__instance.tempCorners[2], backGroundColor, Vector2.Zero);
            __instance.tempVertices[3] = new VertexPositionColorTexture(__instance.tempCorners[0], backGroundColor, Vector2.Zero);
            __instance.tempVertices[4] = new VertexPositionColorTexture(__instance.tempCorners[2], backGroundColor, Vector2.Zero);
            __instance.tempVertices[5] = new VertexPositionColorTexture(__instance.tempCorners[3], backGroundColor, Vector2.Zero);

            spriteBatch.GraphicsDevice.DrawUserPrimitives(PrimitiveType.TriangleList, __instance.tempVertices, 0, 2);

            foreach (KeyValuePair<EntityGrid, VertexPositionColorTexture[]> subVerts in __instance.IndoorsVertices)
            {
                if (!__instance.PositionInIndoorsBuffer.ContainsKey(subVerts.Key) || __instance.PositionInIndoorsBuffer[subVerts.Key] == 0) { continue; }

                offset = __instance.WavePos;
                if (subVerts.Key.Submarine != null) { offset -= subVerts.Key.Submarine.WorldPosition; }
                if (cam != null)
                {
                    offset += cam.Position - new Vector2(cam.WorldView.Width / 2.0f, -cam.WorldView.Height / 2.0f);
                    offset.Y += cam.WorldView.Height;
                    offset.X += cam.WorldView.Width;
                    offset *= WaterRenderer.DistortionScale;
                }
                offset.Y = -offset.Y;
                __instance.WaterEffect.Parameters["xUvOffset"].SetValue(new Vector2((offset.X / GameMain.GraphicsWidth) % 1.0f, (offset.Y / GameMain.GraphicsHeight) % 1.0f));

                __instance.WaterEffect.CurrentTechnique.Passes[0].Apply();

                spriteBatch.GraphicsDevice.DrawUserPrimitives(PrimitiveType.TriangleList, subVerts.Value, 0, __instance.PositionInIndoorsBuffer[subVerts.Key] / 3);
            }

            __instance.WaterEffect.Parameters["xTexture"].SetValue((Texture2D)null);
            __instance.WaterEffect.CurrentTechnique.Passes[0].Apply();

			return false;
        }
		
        public static bool OverrideUpdateStatusHUD(float deltaTime, CharacterHealth __instance)
        {
            if (Character.Controlled?.SelectedCharacter == null && CharacterHealth.openHealthWindow == null)
            {
                __instance.statusIcons.Clear();
				/* 
                if (__instance.Character.InPressure)
                {
                    __instance.statusIcons.Add(__instance.pressureAffliction);
                }
				 */
                if (__instance.Character.CurrentHull != null && __instance.Character.OxygenAvailable < CharacterHealth.LowOxygenThreshold && __instance.oxygenLowAffliction.Strength < __instance.oxygenLowAffliction.Prefab.ShowIconThreshold)
                {
                    __instance.statusIcons.Add(__instance.oxygenLowAffliction);
                }
                
                foreach (Affliction affliction in __instance.currentDisplayedAfflictions)
                {
                    __instance.statusIcons.Add(affliction);
                }

                int spacing = GUI.IntScale(10);
                if (__instance.Character.ShouldLockHud())
                {
                    // Push the icons down since the portrait doesn't get rendered
                    __instance.afflictionIconContainer.RectTransform.ScreenSpaceOffset = new Point(0, HUDLayoutSettings.PortraitArea.Height);
                    __instance.hiddenAfflictionIconContainer.RectTransform.ScreenSpaceOffset = new Point(0, -__instance.hiddenAfflictionIconContainer.Rect.Height - spacing + HUDLayoutSettings.PortraitArea.Height);
                }
                else
                {
                    __instance.afflictionIconContainer.RectTransform.ScreenSpaceOffset = new Point(0, 0);
                   __instance.hiddenAfflictionIconContainer.RectTransform.ScreenSpaceOffset = new Point(0, -__instance.hiddenAfflictionIconContainer.Rect.Height - spacing);
                }
                //remove affliction icons for afflictions that no longer exist

                RemoveNonExistentIcons(__instance.afflictionIconContainer);
                RemoveNonExistentIcons(__instance.hiddenAfflictionIconContainer);
                void RemoveNonExistentIcons(GUIComponent container)
                {
                    for (int i = container.CountChildren - 1; i >= 0; i--)
                    {
                        var child = container.GetChild(i);
                        if (child.UserData is not AfflictionPrefab afflictionPrefab) { continue; }
                        if (!__instance.statusIcons.Any(s => s.Prefab == afflictionPrefab))
                        {
                            container.RemoveChild(child);
                            __instance.statusIconVisibleTime.Remove(afflictionPrefab);
                        }
                    }
                }

                foreach (var statusIcon in __instance.statusIcons)
                {
                    Affliction affliction = statusIcon;
                    AfflictionPrefab afflictionPrefab = affliction.Prefab;

                    if (!__instance.statusIconVisibleTime.ContainsKey(afflictionPrefab)) { __instance.statusIconVisibleTime.Add(afflictionPrefab, 0.0f); }
                    __instance.statusIconVisibleTime[afflictionPrefab] += deltaTime;

                    var matchingIcon = 
                        __instance.afflictionIconContainer.GetChildByUserData(afflictionPrefab) ?? 
                       __instance.hiddenAfflictionIconContainer.GetChildByUserData(afflictionPrefab);
                    if (matchingIcon == null)
                    {
                        matchingIcon = new GUIButton(new RectTransform(new Point(__instance.afflictionIconContainer.Rect.Height), __instance.afflictionIconContainer.RectTransform), style: null)
                        {
                            UserData = afflictionPrefab,
                            ToolTip = affliction.Prefab.Name,
                            CanBeSelected = false
                        };
                        if (affliction == __instance.pressureAffliction)
                        {
                            matchingIcon.ToolTip = TextManager.Get("PressureHUDWarning");
                        }
                        else if (affliction == __instance.pressureAffliction)
                        {
                            matchingIcon.ToolTip = TextManager.Get("OxygenHUDWarning");
                        }
                        new GUIImage(new RectTransform(Vector2.One, matchingIcon.RectTransform, Anchor.BottomCenter), afflictionPrefab.Icon, scaleToFit: true)
                        {
                            CanBeFocused = false                            
                        };
                    }
                    if (afflictionPrefab.HideIconAfterDelay && __instance.statusIconVisibleTime[afflictionPrefab] > CharacterHealth.HideStatusIconDelay)
                    {
                        matchingIcon.RectTransform.Parent = __instance.hiddenAfflictionIconContainer.RectTransform;
                    }
                    var image = matchingIcon.GetChild<GUIImage>();
                    image.Color = CharacterHealth.GetAfflictionIconColor(afflictionPrefab, affliction);
                    image.HoverColor = Color.Lerp(image.Color, Color.White, 0.5f);

                    if (affliction.DamagePerSecond > 1.0f && matchingIcon.FlashTimer <= 0.0f)
                    {
                        matchingIcon.Flash(useCircularFlash: true, flashDuration: 1.5f, flashRectInflate: Vector2.One * 15.0f * GUI.Scale);
                        image.Pulsate(Vector2.One, Vector2.One * 1.2f, 1.0f);
                    }
                }

                __instance.afflictionIconRefreshTimer -= deltaTime;
                if (__instance.afflictionIconRefreshTimer <= 0.0f)
                {
                    __instance.afflictionIconContainer.RectTransform.SortChildren((r1, r2) =>
                    {
                        if (r1.GUIComponent.UserData is not AfflictionPrefab prefab1) { return -1; }
                        if (r2.GUIComponent.UserData is not AfflictionPrefab prefab2) { return 1; }
                        var index1 = __instance.statusIcons.IndexOf(s => s.Prefab == prefab1);
                        var index2 = __instance.statusIcons.IndexOf(s => s.Prefab == prefab2);
                        return index1.CompareTo(index2);
                    });
                    (__instance.afflictionIconContainer as GUILayoutGroup).NeedsToRecalculate = true;
                    __instance.afflictionIconRefreshTimer = CharacterHealth.AfflictionIconRefreshInterval;
                }

                Rectangle hiddenAfflictionHoverArea = __instance.showHiddenAfflictionsButton.Rect;
                foreach (GUIComponent child in __instance.hiddenAfflictionIconContainer.Children)
                {
                    hiddenAfflictionHoverArea = Rectangle.Union(hiddenAfflictionHoverArea, child.Rect);
                }

                __instance.afflictionIconContainer.Visible = true;
                __instance.hiddenAfflictionIconContainer.Visible = 
                    __instance.showHiddenAfflictionsButton.Rect.Contains(PlayerInput.MousePosition) ||
                    (__instance.hiddenAfflictionIconContainer.Visible && hiddenAfflictionHoverArea.Contains(PlayerInput.MousePosition));
                __instance.showHiddenAfflictionsButton.Visible = __instance.hiddenAfflictionIconContainer.CountChildren > 0;
                __instance.showHiddenAfflictionsButton.IgnoreLayoutGroups = !__instance.showHiddenAfflictionsButton.Visible;
                __instance.showHiddenAfflictionsButton.Text = $"+{__instance.hiddenAfflictionIconContainer.CountChildren}";

                if (__instance.Vitality > 0.0f)
                {
                    float currHealth = __instance.healthBar.BarSize;
                    Color prevColor = __instance.healthBar.Color;
                    __instance.healthBarShadow.BarSize = __instance.healthShadowSize;
                    __instance.healthBarShadow.Color = Color.Lerp(GUIStyle.Red, Color.Black, 0.5f);
                    __instance.healthBarShadow.Visible = true;
                    __instance.healthBar.BarSize = currHealth;
                    __instance.healthBar.Color = prevColor;
                }
                else
                {
                    __instance.healthBarShadow.Visible = false;
                }
            }
            else
            {
                __instance.afflictionIconContainer.Visible = __instance.hiddenAfflictionIconContainer.Visible = false;
                if (__instance.Vitality > 0.0f)
                {
                    float currHealth = __instance.healthWindowHealthBar.BarSize;
                    Color prevColor = __instance.healthWindowHealthBar.Color;
                    __instance.healthWindowHealthBarShadow.BarSize = __instance.healthShadowSize;
                    __instance.healthWindowHealthBarShadow.Color = GUIStyle.Red;
                    __instance.healthWindowHealthBarShadow.Visible = true;
                    __instance.healthWindowHealthBar.BarSize = currHealth;
                    __instance.healthWindowHealthBar.Color = prevColor;
                }
                else
                {
                    __instance.healthWindowHealthBarShadow.Visible = false;
                }
            }
			return false;
        }
        // new patches
        public static bool OverrideParticleDraw(Particle __instance, SpriteBatch spriteBatch)
        {
            if(__instance.DrawTarget == ParticlePrefab.DrawTargetType.Water && (__instance.currentHull == null || __instance.position.Y >= __instance.currentHull.Surface)){
                return false;
            }
            if(__instance.DrawTarget == ParticlePrefab.DrawTargetType.Air)
            {
                __instance.Prefab.DrawTarget = ParticlePrefab.DrawTargetType.Both;
            }
            return true;
        }
	}
}