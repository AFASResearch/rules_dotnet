# Copyright 2016 The Bazel Go Rules Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""
Toolchain rules used by dotnet.
"""

load("@bazel_skylib//lib:paths.bzl", "paths")
load("@io_bazel_rules_dotnet//dotnet/private:actions/assembly.bzl", "emit_assembly_core")
load("@io_bazel_rules_dotnet//dotnet/private:actions/resx.bzl", "emit_resx_core")

def _core_toolchain_impl(ctx):
    return [platform_common.ToolchainInfo(
        name = ctx.label.name,
        dotnet_runner = ctx.file.dotnet_runner,
        csc_binary = ctx.file.csc_binary,

        actions = struct(
            assembly = emit_assembly_core,
            resx = emit_resx_core,
        ),
    )]

core_toolchain = rule(
    _core_toolchain_impl,
    attrs = {
        # Minimum requirements to specify a toolchain
        "dotnet_runner": attr.label(mandatory = True, allow_single_file = True),
        "csc_binary": attr.label(mandatory = True, allow_single_file = True),
    },
)
