using System;
using System.Linq;

namespace Lib2
{
    public class Library2
    {
        public int Compute(params string[] args)
        {
            string s = "";
            return args.Append(s).Select(a => a.Length).Sum();
        }

        private object O()
        {
            return null;
        }

        private IEquatable<object> Comp()
        {
            return null;
        }
    }
}
