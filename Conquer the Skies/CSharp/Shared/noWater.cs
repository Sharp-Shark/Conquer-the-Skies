using System;
using System.Reflection;
using System.Globalization;
using System.Collections.Generic;
using System.Linq;
using FarseerPhysics;
using FarseerPhysics.Dynamics;
using FarseerPhysics.Dynamics.Contacts;
using Barotrauma;
using Barotrauma.Extensions;
using Barotrauma.Items.Components;
using Barotrauma.Networking;
using HarmonyLib;
using Microsoft.Xna.Framework;

namespace NoWater
{
    class NoWaterMod : IAssemblyPlugin
    {
        public Harmony harmony;

        public static string MESSAGE_JETSUIT_PARTICLE = "cts_jetsuit_particle";

        public void Initialize()
        {
            harmony = new Harmony("no.water");

            harmony.Patch(
            original: typeof(Ragdoll).GetMethod("UpdateRagdoll"),
            prefix: new HarmonyMethod(typeof(NoWaterMod).GetMethod("OverrideRagdoll"))
            );
            harmony.Patch(
            original: typeof(Ragdoll).GetMethod("FindHull"),
            prefix: new HarmonyMethod(typeof(NoWaterMod).GetMethod("OverrideFindHull"))
            );
            harmony.Patch(
            original: typeof(Gap).GetMethod("UpdateRoomToOut", AccessTools.all),
            prefix: new HarmonyMethod(typeof(NoWaterMod).GetMethod("OverrideUpdateRoomToOut"))
            );
            harmony.Patch(
            original: typeof(Ragdoll).GetMethod("OnLimbCollision"),
            prefix: new HarmonyMethod(typeof(NoWaterMod).GetMethod("OverrideLimbCollision"))
            );
            /* New Patches, not from the No Water Mod */
            // makes items not behave underwater when outside
            harmony.Patch(
            original: typeof(Item).GetMethod("IsInWater", AccessTools.all),
            prefix: new HarmonyMethod(typeof(NoWaterMod).GetMethod("OverrideItemIsInWater"))
            );
            // fixes items colliding with hulls
            harmony.Patch(
            original: typeof(Item).GetMethod("OnCollision", AccessTools.all),
            postfix: new HarmonyMethod(typeof(NoWaterMod).GetMethod("OverrideItemOnCollision"))
            );
            harmony.Patch(
            original: typeof(Item).GetMethod("FindHull", AccessTools.all),
            postfix: new HarmonyMethod(typeof(NoWaterMod).GetMethod("OverrideItemFindHull"))
            );
            // gives grappling hook functionality to harpoons
            harmony.Patch(
            original: typeof(Barotrauma.Items.Components.Rope).GetMethod("Update", AccessTools.all),
            prefix: new HarmonyMethod(typeof(NoWaterMod).GetMethod("OverrideRopeUpdate"))
            );
            // slipsuit has a jetpack
            harmony.Patch(
            original: typeof(Barotrauma.Items.Components.Wearable).GetMethod("Update", AccessTools.all),
            prefix: new HarmonyMethod(typeof(NoWaterMod).GetMethod("OverrideWearableUpdateSlipsuit"))
            );
            harmony.Patch(
            original: typeof(Barotrauma.Items.Components.Propulsion).GetMethod("Use", AccessTools.all),
            prefix: new HarmonyMethod(typeof(NoWaterMod).GetMethod("OverridePropulsionUseSlipsuit"))
            );
            // ungrounds when propelling upwards
            harmony.Patch(
            original: typeof(Barotrauma.Items.Components.Propulsion).GetMethod("Use", AccessTools.all),
            prefix: new HarmonyMethod(typeof(NoWaterMod).GetMethod("OverridePropulsionUse"))
            );
            // uncapped fall damage
            harmony.Patch(
            original: typeof(Ragdoll).GetMethod("GetImpactDamage", AccessTools.all),
            postfix: new HarmonyMethod(typeof(NoWaterMod).GetMethod("OverrideGetImpactDamage"))
            );
            // submarines sink instead of floating when they have no water
            harmony.Patch(
            original: typeof(SubmarineBody).GetMethod("CalculateBuoyancy", AccessTools.all),
            postfix: new HarmonyMethod(typeof(NoWaterMod).GetMethod("OverrideCalculateBuoyancy"))
            );
            harmony.Patch(
            original: typeof(Barotrauma.Items.Components.Steering).GetMethod("Update"),
            postfix: new HarmonyMethod(typeof(NoWaterMod).GetMethod("OverrideSteeringUpdate"))
            );
            // docking ports with the nohull tag will not attempt to create a hull
            harmony.Patch(
            original: typeof(Barotrauma.Items.Components.DockingPort).GetMethod("CreateHulls", AccessTools.all),
            prefix: new HarmonyMethod(typeof(NoWaterMod).GetMethod("OverrideCreateHulls"))
            );
            // disable crush depth
            harmony.Patch(
            original: typeof(Barotrauma.Submarine).GetProperty("AtDamageDepth").GetGetMethod(),
            prefix: new HarmonyMethod(typeof(NoWaterMod).GetMethod("OverrideAtDamageDepth"))
            );
            harmony.Patch(
            original: typeof(Barotrauma.Submarine).GetProperty("AtCosmeticDamageDepth").GetGetMethod(),
            prefix: new HarmonyMethod(typeof(NoWaterMod).GetMethod("OverrideAtCosmeticDamageDepth"))
            );
            harmony.Patch(
            original: typeof(Barotrauma.SubmarineBody).GetMethod("UpdateDepthDamage", AccessTools.all),
            prefix: new HarmonyMethod(typeof(NoWaterMod).GetMethod("OverrideUpdateDepthDamage"))
            );
            harmony.Patch(
            original: typeof(Barotrauma.Character).GetProperty("IsProtectedFromPressure").GetGetMethod(),
            prefix: new HarmonyMethod(typeof(NoWaterMod).GetMethod("OverrideIsProtectedFromPressure"))
            );


#if CLIENT
            GameMain.LuaCs.Networking.Receive(MESSAGE_JETSUIT_PARTICLE, (object[] args) =>
            {
                IReadMessage msg = (IReadMessage)args[0];
                int characterID = msg.ReadUInt16();
                int itemID = msg.ReadUInt16();
                if (Barotrauma.Character.Controlled != null && Barotrauma.Character.Controlled.ID == characterID)
                {
                    return;
                }
                foreach (Item item in Item.ItemList)
                {
                    if (item.ID == itemID)
                    {
                        Barotrauma.Items.Components.Propulsion component = item.GetComponent<Barotrauma.Items.Components.Propulsion>();
                        if (component == null) { return; };
                        if (!string.IsNullOrWhiteSpace(component.particles))
                        {
                            GameMain.ParticleManager.CreateParticle(component.particles, item.WorldPosition,
                                item.body.Rotation + ((item.body.Dir > 0.0f) ? 0.0f : MathHelper.Pi), 0.0f, item.CurrentHull);
                        }
                        return;
                    }
                }
            });
#endif
        }

        public void OnLoadCompleted() { }
        public void PreInitPatching() { }

        public void Dispose()
        {
            harmony.UnpatchSelf();
            harmony = null;
        }

        public static bool OverrideRagdoll(float deltaTime, Camera cam, Ragdoll __instance)
        {
            if (__instance.currentHull != null)
            {
                __instance.RefreshFloorY(deltaTime, ignoreStairs: __instance.Stairs == null);
            }
            // if true, creature can swim in the air when outside a submarine
            bool swimInAir = __instance.character.SpeciesName != "human".ToIdentifier() && (__instance.currentHull == null || !__instance.character.IsHumanoid && (__instance.character.NeedsWater || !__instance.onGround || (Math.Abs(__instance.targetMovement.Y) > 0))) && !__instance.character.IsDead;

            if (!__instance.character.Enabled || __instance.character.Removed || __instance.Frozen || __instance.Invalid || __instance.Collider == null || __instance.Collider.Removed) { return false; }

            while (__instance.impactQueue.Count > 0)
            {
                var impact = __instance.impactQueue.Dequeue();
                __instance.ApplyImpact(impact.F1, impact.F2, impact.LocalNormal, impact.ImpactPos, impact.Velocity);
            }

            __instance.CheckValidity();

            __instance.UpdateNetPlayerPosition(deltaTime);
            __instance.CheckDistFromCollider();
            __instance.UpdateCollisionCategories();
            __instance.FindHull(__instance.WorldPosition);// fixed from crahing
            __instance.PreventOutsideCollision();

            __instance.CheckBodyInRest(deltaTime);

            __instance.splashSoundTimer -= deltaTime;

            if (__instance.character.Submarine == null && Level.Loaded != null)
            {
                if (__instance.Collider.SimPosition.Y > Level.Loaded.TopBarrier.Position.Y)
                {
                    __instance.Collider.LinearVelocity = new Vector2(__instance.Collider.LinearVelocity.X, Math.Min(__instance.Collider.LinearVelocity.Y, -1));
                }
                else if (__instance.Collider.SimPosition.Y < Level.Loaded.BottomBarrier.Position.Y)
                {
                    __instance.Collider.LinearVelocity = new Vector2(__instance.Collider.LinearVelocity.X,
                        MathHelper.Clamp(__instance.Collider.LinearVelocity.Y, Level.Loaded.BottomBarrier.Position.Y - __instance.Collider.SimPosition.Y, 10.0f));
                }
                foreach (Limb limb in __instance.Limbs)
                {
                    if (limb.SimPosition.Y > Level.Loaded.TopBarrier.Position.Y)
                    {
                        limb.body.LinearVelocity = new Vector2(limb.LinearVelocity.X, Math.Min(limb.LinearVelocity.Y, -1));
                    }
                    else if (limb.SimPosition.Y < Level.Loaded.BottomBarrier.Position.Y)
                    {
                        limb.body.LinearVelocity = new Vector2(
                            limb.LinearVelocity.X,
                            MathHelper.Clamp(limb.LinearVelocity.Y, Level.Loaded.BottomBarrier.Position.Y - limb.SimPosition.Y, 10.0f));
                    }
                }
            }

            if (swimInAir)
            {
                __instance.character.PressureProtection = 20000f;
                __instance.inWater = true;
                __instance.headInWater = true;
            }
            else if (__instance.forceStanding)
            {
                __instance.inWater = false;
                __instance.headInWater = false;
                __instance.RefreshFloorY(deltaTime, ignoreStairs: __instance.Stairs == null);
            }
            //ragdoll isn't in any room -> it's in the water + outside is no water dummy
            else if (__instance.currentHull == null)
            {
                __instance.character.PressureProtection = 20000f;
                __instance.inWater = false;
                __instance.headInWater = false;
                __instance.RefreshFloorY(deltaTime, false);
                /* disabled
                if (__instance.TargetMovement.X == 0f)
                {
                    __instance.ForceRefreshFloorY();
                }
                */
            }
            else
            {
                __instance.headInWater = false;
                __instance.inWater = false;
                __instance.RefreshFloorY(deltaTime, ignoreStairs: __instance.Stairs == null);
                if (__instance.currentHull.WaterPercentage > 0.001f)
                {
                    (float waterSurfaceDisplayUnits, float ceilingDisplayUnits) = __instance.GetWaterSurfaceAndCeilingY();
                    float waterSurfaceY = ConvertUnits.ToSimUnits(waterSurfaceDisplayUnits);
                    float ceilingY = ConvertUnits.ToSimUnits(ceilingDisplayUnits);
                    if (__instance.targetMovement.Y < 0.0f)
                    {
                        Vector2 colliderBottom = __instance.GetColliderBottom();
                        __instance.floorY = Math.Min(colliderBottom.Y, __instance.floorY);
                        //check if the bottom of the collider is below the current hull
                        if (__instance.floorY < ConvertUnits.ToSimUnits(__instance.currentHull.Rect.Y - __instance.currentHull.Rect.Height))
                        {
                            //set __instance.floorY to the position of the floor in the hull below the __instance.character
                            var lowerHull = Hull.FindHull(ConvertUnits.ToDisplayUnits(colliderBottom), useWorldCoordinates: false);
                            if (lowerHull != null)
                            {
                                __instance.floorY = ConvertUnits.ToSimUnits(lowerHull.Rect.Y - lowerHull.Rect.Height);
                            }
                        }
                    }
                    float standHeight = __instance.HeadPosition ?? __instance.TorsoPosition ?? __instance.Collider.GetMaxExtent() * 0.5f;
                    if (__instance.Collider.SimPosition.Y < waterSurfaceY)
                    {
                        //too deep to stand up, or not enough room to stand up
                        if (waterSurfaceY - __instance.floorY > standHeight * 0.8f ||
                            ceilingY - __instance.floorY < standHeight * 0.8f)
                        {
                            if (waterSurfaceY < Double.PositiveInfinity)
                            { //gdamn if yor ass is in gap between hull and outside its count water surface like infinity. i am not gonna comprehend math above
                                __instance.inWater = true;
                            }
                        }
                    }
                }
            }

            __instance.UpdateHullFlowForces(deltaTime);

            if (__instance.currentHull != null)
            {
                if (__instance.currentHull.WaterVolume > __instance.currentHull.Volume * 0.95f ||
                    ConvertUnits.ToSimUnits(__instance.currentHull.Surface) > __instance.Collider.SimPosition.Y)
                {
                    __instance.Collider.ApplyWaterForces();
                }
            }

            foreach (Limb limb in __instance.Limbs)
            {
                //find the room which the limb is in
                //the room where the ragdoll is in is used as the "guess", meaning that it's checked first                
                Hull newHull = __instance.currentHull == null ? null : Hull.FindHull(limb.WorldPosition, __instance.currentHull);

                bool prevInWater = limb.InWater;
                limb.InWater = false;

                if (swimInAir)
                {
                    limb.InWater = true;
                    if (limb.type == LimbType.Head) { __instance.headInWater = true; }
                }
                else if (__instance.forceStanding)
                {
                    limb.InWater = false;
                }
                else if (newHull == null)
                {
                    //limb isn't in any room -> it's in the water
                    limb.InWater = false;
                    if (limb.type == LimbType.Head) { __instance.headInWater = false; }
                }
                else if (newHull.WaterVolume > 0.0f && Submarine.RectContains(newHull.Rect, limb.Position))
                {
                    if (limb.Position.Y < newHull.Surface)
                    {
                        limb.InWater = true;
                        __instance.surfaceY = newHull.Surface;
                        if (limb.type == LimbType.Head)
                        {
                            __instance.headInWater = true;
                        }
                    }
                    //the limb has gone through the surface of the water
                    if (Math.Abs(limb.LinearVelocity.Y) > 5.0f && limb.InWater != prevInWater && newHull == limb.Hull)
                    {
#if CLIENT
                        __instance.Splash(limb, newHull);
#endif
                        //if the Character dropped into water, create a wave
                        if (limb.LinearVelocity.Y < 0.0f)
                        {
                            Vector2 impulse = limb.LinearVelocity * limb.Mass;
                            int n = (int)((limb.Position.X - newHull.Rect.X) / Hull.WaveWidth);
                            newHull.WaveVel[n] += MathHelper.Clamp(impulse.Y, -5.0f, 5.0f);
                        }
                    }
                }
                limb.Hull = newHull;
                limb.Update(deltaTime);
            }

            bool isAttachedToController =
                __instance.character.SelectedItem?.GetComponent<Barotrauma.Items.Components.Controller>() is { } controller &&
                controller.User == __instance.character &&
                controller.IsAttachedUser(controller.User);

            if (!__instance.inWater && __instance.character.AllowInput && __instance.levitatingCollider && !isAttachedToController)
            {
                if (__instance.onGround && __instance.Collider.LinearVelocity.Y > -__instance.ImpactTolerance)
                {
                    float targetY = __instance.standOnFloorY + ((float)Math.Abs(Math.Cos(__instance.Collider.Rotation)) * __instance.Collider.Height * 0.5f) + __instance.Collider.Radius + __instance.ColliderHeightFromFloor;

                    const float LevitationSpeedMultiplier = 5f;

                    // If the __instance.character is walking down a slope, target a position that moves along it
                    float slopePull = 0f;
                    if (__instance.floorNormal.Y is > 0f and < 1f
                        && Math.Sign(__instance.movement.X) == Math.Sign(__instance.floorNormal.X))
                    {
                        float steepness = Math.Abs(__instance.floorNormal.X);
                        slopePull = Math.Abs(__instance.movement.X * steepness) / LevitationSpeedMultiplier;
                    }

                    if (Math.Abs(__instance.Collider.SimPosition.Y - targetY - slopePull) > 0.01f)
                    {
                        float yVelocity = (targetY - __instance.Collider.SimPosition.Y) * LevitationSpeedMultiplier;
                        if (__instance.Stairs != null && targetY < __instance.Collider.SimPosition.Y)
                        {
                            yVelocity = Math.Sign(yVelocity);
                        }

                        yVelocity -= slopePull * LevitationSpeedMultiplier;

                        __instance.Collider.LinearVelocity = new Vector2(__instance.Collider.LinearVelocity.X, yVelocity);
                    }
                }
                else
                {
                    // Falling -> ragdoll briefly if we are not moving at all, because we are probably stuck.
                    if (__instance.Collider.LinearVelocity == Vector2.Zero)
                    {
                        __instance.character.IsRagdolled = true;
                        if (__instance.character.IsBot)
                        {
                            // Seems to work without this on player controlled __instance.characters -> not sure if we should call it always or just for the bots.
                            __instance.character.SetInput(InputType.Ragdoll, hit: false, held: true);
                        }
                    }
                }
            }
#if CLIENT
            __instance.UpdateProjSpecific(deltaTime, cam);
#endif
            __instance.forceNotStanding = false;
            return false;
        }

        public static bool OverrideFindHull(Ragdoll __instance, Vector2? worldPosition = null, bool setSubmarine = true)
        {
            Vector2 findPos = worldPosition == null ? __instance.WorldPosition : (Vector2)worldPosition;
            if (!MathUtils.IsValid(findPos))
            {
                GameAnalyticsManager.AddErrorEventOnce(
                    "Ragdoll.FindHull:InvalidPosition",
                    GameAnalyticsManager.ErrorSeverity.Error,
                    "Attempted to find a hull at an invalid position (" + findPos + ")\n" + Environment.StackTrace.CleanupStackTrace());
                return false;
            }

            Hull newHull = Hull.FindHull(findPos, __instance.currentHull);

            if (newHull == __instance.currentHull) { return false; }

            if (__instance.CanEnterSubmarine == CanEnterSubmarine.False ||
                (__instance.character.AIController != null && __instance.character.AIController.CanEnterSubmarine == CanEnterSubmarine.False))
            {
                //character is inside the sub even though it shouldn't be able to enter -> teleport it out

                //far from an ideal solution, but monsters getting lodged inside the sub seems to be 
                //pretty rare during normal gameplay (requires abnormally high velocities), so I think
                //this is preferable to the cost of using continuous collision detection for the character collider
                if (newHull?.Submarine != null)
                {
                    Vector2 hullDiff = __instance.WorldPosition - newHull.WorldPosition;
                    Vector2 moveDir = hullDiff.LengthSquared() < 0.001f ? Vector2.UnitY : Vector2.Normalize(hullDiff);

                    //find a position 32 units away from the hull
                    if (MathUtils.GetLineRectangleIntersection(
                        newHull.WorldPosition,
                        newHull.WorldPosition + moveDir * Math.Max(newHull.Rect.Width, newHull.Rect.Height),
                        new Rectangle(newHull.WorldRect.X - 32, newHull.WorldRect.Y + 32, newHull.WorldRect.Width + 64, newHull.Rect.Height + 64),
                        out Vector2 intersection))
                    {
                        __instance.Collider.SetTransform(ConvertUnits.ToSimUnits(intersection), __instance.Collider.Rotation);
                    }
                    return false;
                }
            }

            if (__instance.CanEnterSubmarine != CanEnterSubmarine.True)
            {
                return false;
            }

            if (__instance.character.SelectedSecondaryItem?.Submarine != null)
            {

            }

            //if (__instance.character.Submarine != null && __instance.OnGround || __instance.IsClimbing? && newHull?.Submarine == null) { return false; }

            if (setSubmarine)
            {
                //in -> out
                if (newHull?.Submarine == null && __instance.currentHull?.Submarine != null)
                {
                    //don't teleport out yet if the character is going through a gap
                    if (Gap.FindAdjacent(Gap.GapList.Where(g => g.Submarine == __instance.currentHull.Submarine), findPos, 150.0f, allowRoomToRoom: true) != null) { return false; }
                    if (__instance.Limbs.Any(l => Gap.FindAdjacent(__instance.currentHull.ConnectedGaps, l.WorldPosition, ConvertUnits.ToDisplayUnits(l.body.GetSize().Combine()), allowRoomToRoom: true) != null)) { return false; }
                    __instance.character.MemLocalState?.Clear();
                    __instance.Teleport(ConvertUnits.ToSimUnits(__instance.currentHull.Submarine.Position), __instance.currentHull.Submarine.Velocity);
                }
                //out -> in
                else if (__instance.currentHull == null && newHull.Submarine != null)
                {
                    __instance.character.MemLocalState?.Clear();
                    __instance.Teleport(-ConvertUnits.ToSimUnits(newHull.Submarine.Position), -newHull.Submarine.Velocity);
                }
                //from one sub to another
                else if (newHull != null && __instance.currentHull != null && newHull.Submarine != __instance.currentHull.Submarine)
                {
                    __instance.character.MemLocalState?.Clear();
                    Vector2 newSubPos = newHull.Submarine == null ? Vector2.Zero : newHull.Submarine.Position;
                    Vector2 prevSubPos = __instance.currentHull.Submarine == null ? Vector2.Zero : __instance.currentHull.Submarine.Position;
                    __instance.Teleport(ConvertUnits.ToSimUnits(prevSubPos - newSubPos), Vector2.Zero);
                }
            }


            __instance.CurrentHull = newHull;
            __instance.character.Submarine = __instance.currentHull?.Submarine;

            foreach (var attachedProjectile in __instance.character.AttachedProjectiles)
            {
                attachedProjectile.Item.CurrentHull = __instance.currentHull;
                attachedProjectile.Item.Submarine = __instance.character.Submarine;
                attachedProjectile.Item.UpdateTransform();
            }
            return false;
        }

        public static bool OverrideLimbCollision(Fixture f1, Fixture f2, Contact contact, Ragdoll __instance)
        {
            __instance.IgnorePlatforms = false;
            if (f2.Body.UserData is Submarine submarine && __instance.character.Submarine == submarine) { return false; }
            if (f2.UserData is Hull)
            {
                if (__instance.character.Submarine != null)
                {
                    return false;
                }
                if (__instance.CanEnterSubmarine == CanEnterSubmarine.Partial)
                {
                    //collider collides with hulls to prevent the character going fully inside the sub, limbs don't
                    return
                        f1.Body == __instance.Collider.FarseerBody ||
                        (f1.Body.UserData is Limb limb && !limb.Params.CanEnterSubmarine);
                }
            }

            //using the velocity of the limb would make the impact damage more realistic,
            //but would also make it harder to edit the animations because the forces/torques
            //would all have to be balanced in a way that prevents the character from doing
            //impact damage to itself
            Vector2 velocity = __instance.Collider.LinearVelocity;
            if (__instance.character.Submarine == null && f2.Body.UserData is Submarine sub)
            {
                velocity -= sub.Velocity;
            }

            //always collides with bodies other than structures
            if (f2.Body.UserData is not Structure structure)
            {
                if (!f2.IsSensor)
                {
                    lock (__instance.impactQueue)
                    {
                        __instance.impactQueue.Enqueue(new Ragdoll.Impact(f1, f2, contact, velocity));
                    }
                }
                return true;
            }
            else if (__instance.character.Submarine != null && structure.Submarine != null && __instance.character.Submarine != structure.Submarine)
            {
                return false;
            }

            Vector2 colliderBottom = __instance.GetColliderBottom();
            if (structure.IsPlatform)
            {
                if (__instance.IgnorePlatforms) { return false; }

                if (colliderBottom.Y < ConvertUnits.ToSimUnits(structure.Rect.Y - 5)) { return false; }
                if (f1.Body.Position.Y < ConvertUnits.ToSimUnits(structure.Rect.Y - 5)) { return false; }
            }
            else if (structure.StairDirection != Direction.None)
            {
                if (__instance.character.SelectedBy != null)
                {
                    __instance.Stairs = __instance.character.SelectedBy.AnimController.Stairs;
                }

                var collisionResponse = getStairCollisionResponse();
                if (collisionResponse == Ragdoll.LimbStairCollisionResponse.ClimbWithLimbCollision)
                {
                    __instance.Stairs = structure;
                }
                else
                {
                    if (collisionResponse == Ragdoll.LimbStairCollisionResponse.DontClimbStairs) { __instance.Stairs = null; }

                    return false;
                }

                Ragdoll.LimbStairCollisionResponse getStairCollisionResponse()
                {
                    //don't collide with stairs if

                    //1. bottom of the collider is at the bottom of the stairs and the character isn't trying to move upwards
                    float stairBottomPos = ConvertUnits.ToSimUnits(structure.Rect.Y - structure.Rect.Height + 10);
                    if (colliderBottom.Y < stairBottomPos && __instance.targetMovement.Y < 0.5f) { return Ragdoll.LimbStairCollisionResponse.DontClimbStairs; }
                    if (__instance.character.SelectedBy != null &&
                        __instance.character.SelectedBy.AnimController.GetColliderBottom().Y < stairBottomPos &&
                        __instance.character.SelectedBy.AnimController.targetMovement.Y < 0.5f)
                    {
                        return Ragdoll.LimbStairCollisionResponse.DontClimbStairs;
                    }

                    //2. bottom of the collider is at the top of the stairs and the character isn't trying to move downwards
                    if (__instance.targetMovement.Y >= 0.0f && colliderBottom.Y >= ConvertUnits.ToSimUnits(structure.Rect.Y - Submarine.GridSize.Y * 5)) { return Ragdoll.LimbStairCollisionResponse.DontClimbStairs; }

                    //3. collided with the stairs from below
                    if (contact.Manifold.LocalNormal.Y < 0.0f)
                    {
                        return __instance.Stairs != structure
                            ? Ragdoll.LimbStairCollisionResponse.DontClimbStairs
                            : Ragdoll.LimbStairCollisionResponse.ClimbWithoutLimbCollision;
                    }

                    //4. contact points is above the bottom half of the collider
                    contact.GetWorldManifold(out _, out FarseerPhysics.Common.FixedArray2<Vector2> points);
                    if (points[0].Y > __instance.Collider.SimPosition.Y) { return Ragdoll.LimbStairCollisionResponse.DontClimbStairs; }

                    //5. in water
                    if (__instance.inWater && __instance.targetMovement.Y < 0.5f) { return Ragdoll.LimbStairCollisionResponse.DontClimbStairs; }

                    return Ragdoll.LimbStairCollisionResponse.ClimbWithLimbCollision;
                }
            }

            lock (__instance.impactQueue)
            {
                __instance.impactQueue.Enqueue(new Ragdoll.Impact(f1, f2, contact, velocity));
            }

            return true;
        }

        public static bool OverrideUpdateRoomToOut(float deltaTime, Hull hull1, Gap __instance)
        {
            float sizeModifier = __instance.Size * __instance.open;

            hull1.Oxygen -= 100.0f * sizeModifier * deltaTime;
            if (hull1.WaterVolume <= 0.0f) { return false; }

            __instance.flowTargetHull = hull1;

            //a variable affecting the water flow through the gap
            //the larger the gap is, the faster the water flows


            //horizontal gap (such as a regular door)
            if (__instance.IsHorizontal)
            {
                float delta = 0.0f;

                //water level is above the lower boundary of the gap


                //water flowing from the righthand room to the lefthand outsidedies
                if (__instance.rect.X > hull1.Rect.X + hull1.Rect.Width / 2.0f)
                {
                    if (hull1.WaveY.Length == 0) { return false; }
                    if (Math.Max(hull1.Surface + hull1.WaveY[hull1.WaveY.Length - 1], 0f) > __instance.rect.Y - __instance.Size)
                    {
                        __instance.lowerSurface = hull1.Surface - hull1.WaveY[hull1.WaveY.Length - 1];

                        //make sure not to move more than what the room contains
                        delta = 300.0f * sizeModifier * deltaTime;

                        //make sure not to remove more water to the target room than it can hold
                        delta = Math.Min(delta, hull1.Volume);
                        hull1.WaterVolume -= delta;

                        __instance.flowForce = new Vector2(delta * (float)(Timing.Step / deltaTime), 0.0f);
                    }
                }
                else
                {
                    if (hull1.WaveY.Length == 0) { return false; }
                    if (Math.Max(hull1.Surface + hull1.WaveY[0], 0f) > __instance.rect.Y - __instance.Size)
                    {
                        __instance.lowerSurface = hull1.Surface - hull1.WaveY[0];

                        //make sure not to move more than what the room contains
                        delta = 300.0f * sizeModifier * deltaTime;

                        //make sure not to remove more water to the target room than it can hold
                        delta = Math.Min(delta, hull1.Volume);
                        hull1.WaterVolume -= delta;

                        __instance.flowForce = new Vector2(-delta * (float)(Timing.Step / deltaTime), 0.0f);
                    }
                }
            }
            else
            {
                //upper gap with room is full of water
                if (__instance.rect.Y > hull1.Rect.Y - hull1.Rect.Height / 2.0f)
                {
                    if (hull1.Volume < hull1.WaterVolume)
                    {
                        float delta = hull1.WaterVolume - hull1.Volume;
                        hull1.WaterVolume -= delta;
                        __instance.flowForce = new Vector2(0.0f, delta * (float)(Timing.Step / deltaTime));
                    }
                }
                //bottom gap there's water in the room, drop to outside
                else if (hull1.WaterVolume > 0)
                {
                    // guard clause
                    if (hull1.WaveVel.Length == 0) { return false; }

                    //make sure the amount of water moved isn't more than what the room contains
                    float delta = Math.Min(hull1.WaterVolume, 300.0f * sizeModifier * deltaTime);

                    hull1.WaterVolume -= delta;

                    __instance.flowForce = new Vector2(0f, -delta * (float)(Timing.Step / deltaTime));
                    int n = hull1.GetWaveIndex(__instance.rect.X + (__instance.rect.Width * 0.5f));
                    //syphon effect?
                    float vel = __instance.flowForce.Y * deltaTime * 0.1f;
                    if (n < hull1.WaveVel.Length) { hull1.WaveVel[n] += vel; }
                    if (n + 1 < hull1.WaveVel.Length) { hull1.WaveVel[n + 1] += vel; }
                }
            }
            if (hull1.WaterVolume < 5f)
            {

            }
            return false;
        }
        // new methods
        public static bool OverrideItemIsInWater(Item __instance, ref bool __result)
        {
            __result = false;
            if (__instance.CurrentHull == null)
            {
                __result = false;
                return false;
            }
            float surfaceY = __instance.CurrentHull.Surface;
            if (__instance.CurrentHull.WaterVolume > 0f)
            {
                __result = __instance.Position.Y < surfaceY;
            }
            return false;
        }
        public static void OverrideItemOnCollision(Item __instance, Fixture f1, Fixture f2, Contact contact, ref bool __result)
        {
            if (__result == false) { return; }
            if (f2.Body.UserData is Submarine sub)
            {
                Item item = __instance;
                Vector2 normalizedVel;
                Vector2 dir;
                if (item.body.LinearVelocity.LengthSquared() < 0.001f)
                {
                    normalizedVel = Vector2.Zero;
                    dir = contact.Manifold.LocalNormal;
                }
                else
                {
                    normalizedVel = (dir = Vector2.Normalize(item.body.LinearVelocity));
                }
                Body wallBody = Submarine.PickBody(item.body.SimPosition - ConvertUnits.ToSimUnits(sub.Position) - dir, item.body.SimPosition - ConvertUnits.ToSimUnits(sub.Position) + dir, null, Category.Cat1, ignoreSensors: true, (Fixture f) => true);
                if (wallBody?.FixtureList?.First() == null || (!(wallBody.UserData is Structure) && !(wallBody.UserData is Item)))
                {
                    __result = false;
                }
            }
        }
        public static void OverrideItemFindHull(Item __instance, ref Hull __result)
        {
            if (__result != null) { return; }
            if (__instance.body == null || !__instance.body.Enabled || __instance.body.BodyType != BodyType.Dynamic) { return; }
            if (__instance.body.LinearVelocity.Y > 0) { return; }
            if (__instance.GetComponent<Barotrauma.Items.Components.Projectile>() != null) { return; }

            float height = MathHelper.Max(__instance.body.Height, __instance.body.Radius) * 100 + 4;
            Hull newHull = Hull.FindHull(__instance.WorldPosition + new Vector2(0, -height), null, true, true);

            if (newHull != null)
            {
                if (newHull.Submarine != null)
                {
                    __instance.Submarine = newHull.Submarine;
                    __instance.body.Submarine = newHull.Submarine;
                }
                __instance.CurrentHull = newHull;
                __result = newHull;
            }
        }
        public static void OverrideRopeUpdate(Barotrauma.Items.Components.Rope __instance, float deltaTime, Camera cam)
        {
            Barotrauma.Items.Components.Projectile projectile = __instance.item.GetComponent<Barotrauma.Items.Components.Projectile>();
            Character user = __instance.item.GetComponent<Barotrauma.Items.Components.Projectile>()?.User;
            if (__instance.source == null || __instance.target == null || __instance.target.Removed ||
                __instance.source is Entity { Removed: true } ||
                __instance.source is Limb { Removed: true } ||
                user is { Removed: true })
            {
                return;
            }
            if (projectile == null || !projectile.IsStuckToTarget) { return; }
            if (__instance.Snapped || !__instance.target.HasTag("harpoonammo") || user == null || user.Removed || user.AnimController.IsClimbing) { return; }

            Vector2 diff = __instance.target.WorldPosition - __instance.GetSourcePos();
            Vector2 vector = Vector2.Normalize(diff) * Math.Min(0.7f, diff.Length() / 200f);
            Vector2 move = Vector2.Normalize(user.AnimController.TargetMovement) / 16f;

            // holding crouch disables pull
            if (user.IsKeyDown(InputType.Crouch))
            {
                vector *= 0f;
            }
            else
            {
                user.AnimController.onGround = false;
            }

            user.AnimController.Collider.LinearVelocity *= 0.95f;
            user.AnimController.Collider.LinearVelocity += vector;
            user.AnimController.Collider.LinearVelocity += move;
            foreach (Limb limb in user.AnimController.Limbs)
            {
                limb.body.LinearVelocity *= 0.95f;
                limb.body.LinearVelocity += vector;
                limb.body.LinearVelocity += move;
            }
            return;
        }
        public static void OverrideWearableUpdateSlipsuit(Barotrauma.Items.Components.Wearable __instance, float deltaTime, Camera cam)
        {
            if (__instance.item.Prefab.Identifier != "slipsuit".ToIdentifier()) { return; }
            Character character = __instance.picker;
            __instance.item.Use(deltaTime, character);
        }
        public static bool OverridePropulsionUseSlipsuit(Barotrauma.Items.Components.Propulsion __instance, float deltaTime, Character character, ref bool __result)
        {
            if (__instance.item.Prefab.Identifier != "slipsuit".ToIdentifier()) { return true; }
            if (character == null || character.Removed) { return false; }
            if (!character.IsKeyDown(InputType.Run) || character.Stun > 0.0f) { return false; }
            if (__instance.UsableIn == Barotrauma.Items.Components.Propulsion.UseEnvironment.None) { return false; }

            __instance.IsActive = true;
            __instance.useState = 0.1f;

            if (character.AnimController.InWater)
            {
                if (__instance.UsableIn == Barotrauma.Items.Components.Propulsion.UseEnvironment.Air) { return false; }
            }
            else
            {
                if (__instance.UsableIn == Barotrauma.Items.Components.Propulsion.UseEnvironment.Water) { return false; }
            }

            Vector2 move = new Vector2((character.IsKeyDown(InputType.Right) ? 1.0f : 0.0f) - (character.IsKeyDown(InputType.Left) ? 1.0f : 0.0f),
            (character.IsKeyDown(InputType.Up) ? 1.0f : 0.0f) - (character.IsKeyDown(InputType.Down) ? 1.0f : 0.0f));
            move.Y = MathHelper.Max(0, move.Y); // when going down, just freefall instead
            if (move.LengthSquared() <= 0) { return false; }

            Vector2 dir = Vector2.Normalize(move) * 0.6f;
            if (dir.LengthSquared() <= 0) { return false; }
            if (!MathUtils.IsValid(dir)) { return false; }
            Vector2 propulsion = dir * __instance.Force * 2.0f * character.PropulsionSpeedMultiplier * (1.0f + character.GetStatValue(StatTypes.PropulsionSpeed));
            character.AnimController.onGround = false;

            character.AnimController.Collider.ApplyForce(propulsion);

#if CLIENT
            if (!string.IsNullOrWhiteSpace(__instance.particles))
            {
                GameMain.ParticleManager.CreateParticle(__instance.particles, __instance.item.WorldPosition,
                    __instance.item.body.Rotation + ((__instance.item.body.Dir > 0.0f) ? 0.0f : MathHelper.Pi), 0.0f, __instance.item.CurrentHull);
            }
#endif
#if SERVER
            foreach (Barotrauma.Networking.Client client in Barotrauma.Networking.Client.ClientList)
            {
                IWriteMessage message = GameMain.LuaCs.Networking.Start(MESSAGE_JETSUIT_PARTICLE);
                message.WriteUInt16(character.ID);
                message.WriteUInt16(__instance.item.ID);
                GameMain.LuaCs.Networking.Send(message, client.Connection);
            }
#endif

            __result = true;
            return false;
        }
        public static void OverridePropulsionUse(Barotrauma.Items.Components.Propulsion __instance, float deltaTime, Character character)
        {
            if (!__instance.IsActive) { return; }

            Vector2 dir = character.CursorPosition - character.Position;
            if (dir.X > 0 && character.AnimController.TargetDir != Barotrauma.Direction.Right)
            {
                character.AnimController.TargetDir = Barotrauma.Direction.Right;

            } else if (dir.X < 0 && character.AnimController.TargetDir != Barotrauma.Direction.Left)
            {
                character.AnimController.TargetDir = Barotrauma.Direction.Left;
            }

            if (__instance.item.Prefab.Identifier == "slipsuit".ToIdentifier()) { return; }

            if (dir.Y * __instance.Force <= 0 || character.IsKeyDown(InputType.Crouch)) { return; }

            character.AnimController.onGround = false;
        }
        public static void OverrideGetImpactDamage(Ragdoll __instance, ref float __result, float impact, float? impactTolerance = null)
        {
            float tolerance = impactTolerance ?? __instance.ImpactTolerance;
            __result = (impact - tolerance) * 10f;
            return;
        }
        public static void OverrideCalculateBuoyancy(SubmarineBody __instance, ref Vector2 __result)
        {
            __result.Y = __result.Y * -1;
            return;
        }
        public static void OverrideSteeringUpdate(Barotrauma.Items.Components.Steering __instance, float deltaTime, Camera cam)
        {
            Submarine controlledSub = __instance.item.Submarine;
            Sonar sonar = __instance.item.GetComponent<Sonar>();
            if (sonar != null && sonar.UseTransducers)
            {
                controlledSub = (sonar.ConnectedTransducers.Any() ? sonar.ConnectedTransducers.First().Item.Submarine : null);
            }

            if (!__instance.HasPower)
            {
                return;
            }

            float velX = __instance.targetVelocity.X;
            if (controlledSub != null && controlledSub.FlippedX)
            {
                velX *= -1f;
            }
            __instance.item.SendSignal(new Signal(velX.ToString(CultureInfo.InvariantCulture), 0, __instance.user), "velocity_x_out");

            float velY = MathHelper.Lerp((__instance.neutralBallastLevel * 100f - 50f) * 2f, -100 * Math.Sign(__instance.targetVelocity.Y), Math.Abs(__instance.targetVelocity.Y) / 100f);
            velY *= -1; // only change compared to vanilla
            __instance.item.SendSignal(new Signal(velY.ToString(CultureInfo.InvariantCulture), 0, __instance.user), "velocity_y_out");
        }
        public static bool OverrideCreateHulls(Barotrauma.Items.Components.DockingPort __instance)
        {
            if (__instance.DockingTarget == null) { return false; }
            return !__instance.item.HasTag("nohull") && !__instance.DockingTarget.item.HasTag("nohull");
        }
        public static bool OverrideAtDamageDepth(ref bool __result)
        {
            __result = false;
            return false;
        }
        public static bool OverrideAtCosmeticDamageDepth(ref bool __result)
        {
            __result = false;
            return false;
        }
        public static bool OverrideUpdateDepthDamage()
        {
            return false;
        }
        public static bool OverrideIsProtectedFromPressure(ref bool __result)
        {
            __result = true;
            return false;
        }
    }
}