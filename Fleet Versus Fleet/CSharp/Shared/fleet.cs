using System;
using System.Reflection;
using System.Globalization;
using System.Collections.Generic;
using System.Linq;
using Barotrauma;
using HarmonyLib;
using MoonSharp.Interpreter;

namespace Fleet
{
    class FleetMod : IAssemblyPlugin
    {
        public Harmony harmony;

        public void Initialize()
        {
            harmony = new Harmony("fleet");
			
			UserData.RegisterType<Barotrauma.Option<Barotrauma.SubmarineInfo>>();
        }

        public void OnLoadCompleted() { }
        public void PreInitPatching() { }

        public void Dispose()
        {
            harmony.UnpatchSelf();
            harmony = null;
        }
		
		public static Barotrauma.Option<Barotrauma.SubmarineInfo> OptionSubmarineInfo(Barotrauma.SubmarineInfo info)
		{
			return Barotrauma.Option.Some(info);
		}
	}
}