using System;
using Lib;
using Lib2;
using Something;

namespace Example
{
    class Program
    {
        static void Main(string[] args)
        {
            Console.WriteLine(new Library().Compute("Hello World!"));
            Console.WriteLine(new Library2().Compute("Hello World!"));
        }
    }
}
