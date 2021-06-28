using System;
using System.Linq;

namespace Lib
{
    public class Library
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
