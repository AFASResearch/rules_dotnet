using System.Collections;
using System.IO;
using Microsoft.Build.Tasks.ResourceHandling;

namespace simpleresgen
{
    public class Translator
    {
        public void Translate(string infile, string outfile)
        {
            var writer = new System.Resources.ResourceWriter(outfile);

            foreach(var resource in MSBuildResXReader.GetResourcesFromFile(infile, pathsRelativeToBasePath: true))
            {
                resource.AddTo(writer);
            }

            writer.Generate();
            writer.Close();
        }
    }
}
