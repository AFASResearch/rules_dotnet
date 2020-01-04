using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace nuget2bazel
{
    public class WorkspaceWriter
    {
        const string _beginHeader = "### Generated by the tool";
        const string _endHeader = "### End of generated by the tool";
        public string AddEntry(string currentWorkspace, WorkspaceEntry toadd, bool indent)
        {
            var section = ExtractSection(currentWorkspace);
            var parser = new WorkspaceParser(section);
            var parsed = parser.Parse().Where(x => x.Name.ToLower() != toadd.Name.ToLower()).ToList();
            parsed.Add(toadd);

            var sb = new StringBuilder();
            foreach (var entry in parsed)
                sb.Append(entry.Generate(indent));
            var newSection = sb.ToString();

            return replaceSection(currentWorkspace, newSection, indent);
        }

        public string RemoveEntry(string currentWorkspace, string toremove, bool indent)
        {
            var section = ExtractSection(currentWorkspace);
            var parser = new WorkspaceParser(section);
            var parsed = parser.Parse().Where(x => x.PackageIdentity.Id.ToLower() != toremove.ToLower());

            var sb = new StringBuilder();
            foreach (var entry in parsed)
                sb.Append(entry.Generate(indent));
            var newSection = sb.ToString();

            return replaceSection(currentWorkspace, newSection, indent);
        }

        public string ExtractSection(string currentWorkspace)
        {
            // Locate the section that contains nuget references
            var pos = currentWorkspace.IndexOf(_beginHeader);
            if (pos < 0)
                return "";

            var rpos = currentWorkspace.IndexOf(_endHeader, pos + _beginHeader.Length);
            if (rpos < 0)
                return "";

            return currentWorkspace.Substring(pos + _beginHeader.Length, rpos - pos - _beginHeader.Length);
        }

        private string replaceSection(string currentWorkspace, string newSection, bool indent)
        {
            var i = indent ? "    " : "";
            // Locate the section that contains nuget references
            var pos = currentWorkspace.IndexOf(_beginHeader);
            if (pos < 0)
                return $"{currentWorkspace}\n{_beginHeader}\n{newSection}{i}{_endHeader}\n";

            var rpos = currentWorkspace.IndexOf(_endHeader, pos + _beginHeader.Length);
            if (rpos < 0)
                return $"{currentWorkspace}\n{_beginHeader}\n{newSection}{i}{_endHeader}\n";

            return $"{currentWorkspace.Substring(0, pos)}{_beginHeader}\n{newSection}{i}{currentWorkspace.Substring(rpos, currentWorkspace.Length - rpos)}";
        }
    }
}
