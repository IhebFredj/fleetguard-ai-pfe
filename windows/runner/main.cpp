#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

// Fix for Firebase C++ SDK linking issue with MSBuild 17.10+
// This provides the missing symbol that was removed/inlined in recent MSVC versions
// but is still expected by the pre-built Firebase flatbuffers library.
extern "C" {
    unsigned __int64 __cdecl __std_find_first_of_trivial_pos_1(
        const char * const _First1,
        unsigned __int64 _Count1,
        const char * const _First2,
        unsigned __int64 _Count2) {
        
        for (unsigned __int64 i = 0; i < _Count1; ++i) {
            for (unsigned __int64 j = 0; j < _Count2; ++j) {
                if (_First1[i] == _First2[j]) {
                    return i;
                }
            }
        }
        return static_cast<unsigned __int64>(-1);
    }
}

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"fleetguard", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
