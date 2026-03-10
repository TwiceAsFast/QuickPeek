//
//  ContentView.swift
//  QuickPeek
//
//  Created by 경민기 on 12/12/25.
//

import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct ContentView: View {
    @EnvironmentObject private var zipManager: ZipManager
    @State private var currentImage: NSImage?
    @State private var currentImagePath: String?
    @State private var imagePaths: [String] = []
    @State private var currentIndex: Int = 0
    @State private var showMenu: Bool = true
    @State private var showFileInfo: Bool = false
    @State private var showNextFileInfo: Bool = false
    @State private var nextFileName: String = ""
    @State private var zipMode: Bool = false
    @State private var zipFiles: [String] = []
    @State private var currentZipIndex: Int = 0
    @State private var imagesInCurrentZip: [String] = []
    @State private var allFilesList: [String] = []
    @State private var allFilesIndex: Int = 0
    @State private var savedDirectory: String?
    
    // 읽기 방향 UI 표시용 상태
    @State private var showDirectionInfo: Bool = false
    @State private var directionIconName: String = ""
    
    // 지원하는 이미지 파일 형식
    
    // 지원하는 이미지 파일 형식
    private let supportedImageTypes: [UTType] = [
        .jpeg, .png, .gif, .bmp
    ]
    
    // 지원하는 이미지 파일 확장자
    private let supportedImageExtensions: [String] = [
        "jpg", "jpeg", "png", "gif", "bmp", "webp"
    ]
    
    var body: some View {
        ZStack {
            // 배경색
            Color.black.ignoresSafeArea()
            
            // 이미지 표시 영역
            if let image = currentImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack {
                    Image(systemName: "photo")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("이미지를 열려면 여기를 클릭하거나 파일을 드래그하세요")
                        .foregroundColor(.gray)
                        .padding(.top, 10)
                }
                .onTapGesture {
                    openFile()
                }
            }
            
            // 메뉴 표시
            if showMenu {
                VStack {
                    HStack {
                        Spacer()
                        
                        if currentImagePath != nil {
                            if zipMode {
                                Text("ZIP 이미지 \(currentIndex + 1) / \(imagesInCurrentZip.count)")
                                    .foregroundColor(.white)
                                Text(" - \(URL(fileURLWithPath: currentImagePath!).lastPathComponent)")
                                    .foregroundColor(.white)
                                    .font(.caption)
                            } else {
                                Text("이미지 \(currentIndex + 1) / \(imagePaths.count)")
                                    .foregroundColor(.white)
                                Text(" - \(URL(fileURLWithPath: currentImagePath!).lastPathComponent)")
                                    .foregroundColor(.white)
                                    .font(.caption)
                            }
                        }
                    }
                    .padding()
                    .background(Color.black.opacity(0.7))
                    
                    Spacer()
                }
            }
            
            // 파일 정보 표시
            if showFileInfo, let path = currentImagePath {
                VStack {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("파일 정보")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text(URL(fileURLWithPath: path).lastPathComponent)
                                .foregroundColor(.white)
                            
                            if let image = currentImage {
                                Text("크기: \(image.size.width) x \(image.size.height)")
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(10)
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(8)
                        
                        Spacer()
                    }
                    .padding(.leading, 20)
                    .padding(.top, 20)
                    
                    Spacer()
                }
            }
            
            // 다음 파일 정보 표시
            if showNextFileInfo {
                VStack {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("다음 파일")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text(nextFileName)
                                .foregroundColor(.white)
                        }
                        .padding(15)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(10)
                        
                        Spacer()
                    }
                    .padding(.leading, 20)
                    .padding(.top, 20)
                    
                    Spacer()
                }
                .onAppear {
                    // 2초 후 자동으로 숨김
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        self.showNextFileInfo = false
                    }
                }
            }
            
            
            // 읽기 방향 정보 표시 (화살표 아이콘)
            if showDirectionInfo {
                VStack {
                    Spacer()
                    Image(systemName: directionIconName)
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                        .padding(30)
                        .background(Color.black.opacity(0.7))
                        .clipShape(Circle())
                        .padding(.bottom, 50)
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.showDirectionInfo = false
                    }
                }
            }
        }
        .onAppear {
            setupKeyHandlers()
            // 프로그램 시작 시 파일이 없으면 열기 창 표시
            if currentImage == nil {
                openFile()
            }
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers: providers)
        }
        .onOpenURL { url in
            processSelectedURL(url)
        }
    }
    
    private func openFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowedContentTypes = supportedImageTypes + [.zip]
        
        if panel.runModal() == .OK, let url = panel.url {
            processSelectedURL(url)
        }
    }
    
    private func processSelectedURL(_ url: URL) {
        if url.hasDirectoryPath {
            let dirURL = url
            
            // 북마크 확인
            if let bookmarkedURL = PermissionManager.shared.resolveBookmark(for: dirURL.path) {
                // 이미 권한이 있는 경우
                defer { bookmarkedURL.stopAccessingSecurityScopedResource() }
                savedDirectory = bookmarkedURL.path
                createAllFilesListFromDirectory(bookmarkedURL.path)
                updateZipFilesList(in: bookmarkedURL.path)
                if let first = allFilesList.first {
                    loadFile(at: first)
                }
            } else if dirURL.startAccessingSecurityScopedResource() {
                // 새로운 권한 획득 및 저장
                defer { dirURL.stopAccessingSecurityScopedResource() }
                PermissionManager.shared.saveBookmark(for: dirURL)
                
                savedDirectory = dirURL.path
                createAllFilesListFromDirectory(dirURL.path)
                updateZipFilesList(in: dirURL.path)
                // 폴더 선택 시 첫 항목 자동 오픈
                if let first = allFilesList.first {
                    loadFile(at: first)
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    showPermissionAlertAndRetryOpenPanel(for: dirURL)
                }
            }
        } else {
            // 파일 선택 플로우 (기존과 동일)
            loadFile(at: url.path)
            let dirURL = url.deletingLastPathComponent()
            
            // 북마크 확인
            if let bookmarkedURL = PermissionManager.shared.resolveBookmark(for: dirURL.path) {
                defer { bookmarkedURL.stopAccessingSecurityScopedResource() }
                savedDirectory = bookmarkedURL.path
                createAllFilesListFromDirectory(bookmarkedURL.path)
                if url.pathExtension.lowercased() == "zip" {
                    updateZipFilesList(in: bookmarkedURL.path)
                }
            } else if dirURL.startAccessingSecurityScopedResource() {
                defer { dirURL.stopAccessingSecurityScopedResource() }
                PermissionManager.shared.saveBookmark(for: dirURL)
                
                savedDirectory = dirURL.path
                createAllFilesListFromDirectory(dirURL.path)
                if url.pathExtension.lowercased() == "zip" {
                    updateZipFilesList(in: dirURL.path)
                }
            } else {
                // 단일 파일만 열린 경우 (권한 없는 경우)
                // Finder에서 열었을 때 폴더 권한이 없을 수 있음
                // 이 경우 현재 파일만 표시하고 파일 리스트는 비워두거나 현재 파일만 포함
                print("폴더 접근 권한 없음: \(dirURL.path)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    showPermissionAlertAndRetryOpenPanel(for: dirURL)
                }
            }
        }
    }
    
    private func updateZipFilesList(in directory: String) {
        do {
            let files = try FileManager.default.contentsOfDirectory(atPath: directory)
            zipFiles = files
                .filter { $0.lowercased().hasSuffix(".zip") }
                .sorted()
                .map { "\(directory)/\($0)" }
        } catch {
            print("ZIP 파일 목록 업데이트 오류: \(error)")
        }
    }
    
    private func loadFile(at path: String) {
        if path.lowercased().hasSuffix(".zip") {
            loadZipFile(at: path)
        } else if isImageFile(path: path) {
            loadImage(at: path)
        }
    }
    
    private func isImageFile(path: String) -> Bool {
        let fileURL = URL(fileURLWithPath: path)
        let fileExtension = fileURL.pathExtension.lowercased()
        return supportedImageTypes.contains { $0.preferredFilenameExtension == fileExtension } ||
               supportedImageExtensions.contains(fileExtension)
    }
    
    private func loadImage(at path: String) {
        if let image = NSImage(contentsOfFile: path) {
            currentImage = image
            currentImagePath = path
            
            zipMode = false
        }
    }
    
    private func loadZipFile(at path: String) {
        zipMode = true
        currentZipIndex = zipFiles.firstIndex(of: path) ?? 0
        
        // ZIP 파일에서 이미지 목록 로드
        let images = zipManager.loadZipFile(at: path)
        
        if !images.isEmpty {
            imagesInCurrentZip = images
            
            // Check readability of first image path
            let firstImagePath = imagesInCurrentZip[0]
            if !FileManager.default.isReadableFile(atPath: firstImagePath) {
                showPermissionAlertAndRetryOpenPanel(for: URL(fileURLWithPath: path).deletingLastPathComponent())
                return
            }
            
            currentIndex = 0
            // ZIP 파일 열 때 첫 번째 이미지를 열도록 함
            if FileManager.default.isReadableFile(atPath: firstImagePath) {
                if let firstImage = NSImage(contentsOfFile: firstImagePath) {
                    currentImage = firstImage
                    currentImagePath = firstImagePath
                }
            } else {
                showPermissionAlertAndRetryOpenPanel(for: URL(fileURLWithPath: path).deletingLastPathComponent())
            }
        } else {
            // ZIP 파일에 이미지가 없으면 다음 ZIP 파일로 이동
            if currentZipIndex < zipFiles.count - 1 {
                nextZipFile()
            } else {
                // 더 이상 ZIP 파일이 없으면 ZIP 모드 종료
                zipMode = false
                showFileInfo = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.showFileInfo = false
                }
            }
        }
    }
    
    private func createAllFilesListFromDirectory(_ directory: String) {
        do {
            let files = try FileManager.default.contentsOfDirectory(atPath: directory)
            
            // 이미지 파일 목록
            imagePaths = files
                .filter { isImageFile(path: "\(directory)/\($0)") }
                .sorted()
                .map { "\(directory)/\($0)" }
            
            // ZIP 파일 목록
            zipFiles = files
                .filter { $0.lowercased().hasSuffix(".zip") }
                .sorted()
                .map { "\(directory)/\($0)" }
            
            // 전체 목록 생성 (이미지 + ZIP)
            allFilesList = (imagePaths + zipFiles).sorted()
            
            if let index = allFilesList.firstIndex(of: currentImagePath ?? "") {
                allFilesIndex = index
            }
        } catch {
            print("디렉토리 읽기 오류: \(error)")
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.canLoadObject(ofClass: URL.self) {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url = url {
                        DispatchQueue.main.async {
                            self.loadFile(at: url.path)
                            
                            let dirURL = url.hasDirectoryPath ? url : url.deletingLastPathComponent()
                            
                            // 북마크 확인
                            if let bookmarkedURL = PermissionManager.shared.resolveBookmark(for: dirURL.path) {
                                defer { bookmarkedURL.stopAccessingSecurityScopedResource() }
                                self.savedDirectory = bookmarkedURL.path
                                self.createAllFilesListFromDirectory(bookmarkedURL.path)
                                if url.pathExtension.lowercased() == "zip" {
                                    self.updateZipFilesList(in: bookmarkedURL.path)
                                }
                                if url.hasDirectoryPath {
                                    if let first = self.allFilesList.first {
                                        self.loadFile(at: first)
                                    }
                                }
                            } else if dirURL.startAccessingSecurityScopedResource() {
                                defer { dirURL.stopAccessingSecurityScopedResource() }
                                PermissionManager.shared.saveBookmark(for: dirURL)
                                
                                self.savedDirectory = dirURL.path
                                self.createAllFilesListFromDirectory(dirURL.path)
                                if url.pathExtension.lowercased() == "zip" {
                                    self.updateZipFilesList(in: dirURL.path)
                                }
                                if url.hasDirectoryPath {
                                    // 폴더 드롭 시 전체 목록 생성 후 첫 항목 자동 오픈
                                    if let first = self.allFilesList.first {
                                        self.loadFile(at: first)
                                    }
                                }
                            } else {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    self.showPermissionAlertAndRetryOpenPanel(for: dirURL)
                                }
                            }
                        }
                    }
                }
                return true
            }
        }
        return false
    }
    
    private func setupKeyHandlers() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // 문자 키 처리
            if let characters = event.characters {
                switch characters {
                case "\t": // Tab
                    showMenu.toggle()
                    return nil
                case "o", "O": // cmd+o 또는 o 단독
                    if event.modifierFlags.contains(.command) {
                        openFile()
                    } else {
                        openZipPickerInCurrentDirectory()
                    }
                    return nil
                case "\u{1b}": // ESC
                    NSApplication.shared.terminate(nil)
                    return nil
                case "[":
                    handleLeftBracketKey()
                    return nil
                case "]":
                    handleRightBracketKey()
                    return nil
                case "~", "`": // 파일 정보
                    showFileInfo.toggle()
                    return nil
                case "d", "D": // 읽기 방향 전환
                    // ZipManager의 상태를 변경
                    self.zipManager.isRightToLeft.toggle()
                    
                    // UI 업데이트 (메인 스레드 보장)
                    DispatchQueue.main.async {
                        self.directionIconName = self.zipManager.isRightToLeft ? "arrow.left" : "arrow.right"
                        self.showDirectionInfo = true
                    }
                    return nil
                default:
                    break
                }
            }
            
            // 키 코드 처리 (방향키, 스페이스바)
            // 주의: 클로저 내에서 self.zipManager를 참조하여 최신 상태를 가져옴
            switch event.keyCode {
            case 123: // 왼쪽 방향키
                if self.zipManager.isRightToLeft {
                    nextImage()
                } else {
                    previousImage()
                }
                return nil
            case 124: // 오른쪽 방향키
                if self.zipManager.isRightToLeft {
                    previousImage()
                } else {
                    nextImage()
                }
                return nil
            case 126: // 위쪽 방향키
                previousImage()
                return nil
            case 125, 49: // 아래쪽 방향키, 스페이스바
                nextImage()
                return nil
            default:
                return event
            }
        }
    }
    
    private func handleLeftBracketKey() {
        // 전체 목록에서 ZIP 파일 목록만 추출
        let zipFilesOnly = allFilesList.filter { $0.lowercased().hasSuffix(".zip") }
        guard !zipFilesOnly.isEmpty else { return }

        let targetZipPath: String

        if zipMode, let currentZip = zipManager.currentZipPath, let currentIndex = zipFilesOnly.firstIndex(of: currentZip) {
            // ZIP 모드: 이전 ZIP으로 이동 (순환)
            let prevIndex = currentIndex > 0 ? currentIndex - 1 : zipFilesOnly.count - 1
            targetZipPath = zipFilesOnly[prevIndex]
        } else {
            // 이미지 모드: 현재 파일 앞에 있는 가장 가까운 ZIP 찾기
            let currentPath = currentImagePath ?? ""
            if let idx = allFilesList.firstIndex(of: currentPath) {
                let prefix = allFilesList[..<idx]
                if let prevZip = prefix.last(where: { $0.lowercased().hasSuffix(".zip") }) {
                    targetZipPath = prevZip
                } else {
                    // 앞쪽에 없으면 마지막 ZIP (순환)
                    targetZipPath = zipFilesOnly.last!
                }
            } else {
                // 현재 파일 못 찾으면 마지막 ZIP
                targetZipPath = zipFilesOnly.last!
            }
        }

        // 해당 ZIP을 로드하고 첫 번째 이미지를 연다
        let didLoad = withSecurityScopedAccessForZip(at: targetZipPath) {
            loadZipFile(at: targetZipPath)
            if let firstImagePath = imagesInCurrentZip.first, FileManager.default.isReadableFile(atPath: firstImagePath) {
                if let firstImage = NSImage(contentsOfFile: firstImagePath) {
                    currentIndex = 0
                    currentImage = firstImage
                    currentImagePath = firstImagePath
                }
            } else {
                showPermissionAlertAndRetryOpenPanel(for: URL(fileURLWithPath: targetZipPath).deletingLastPathComponent())
            }
        }
        guard didLoad else {
            showZipPermissionAlert(for: targetZipPath)
            return
        }

        nextFileName = URL(fileURLWithPath: targetZipPath).lastPathComponent
        showNextFileInfo = true
    }
    
    private func handleRightBracketKey() {
        // 전체 목록에서 ZIP 파일 목록만 추출
        let zipFilesOnly = allFilesList.filter { $0.lowercased().hasSuffix(".zip") }
        guard !zipFilesOnly.isEmpty else { return }

        let targetZipPath: String

        if zipMode, let currentZip = zipManager.currentZipPath, let currentIndex = zipFilesOnly.firstIndex(of: currentZip) {
            // ZIP 모드: 다음 ZIP으로 이동 (순환)
            let nextIndex = (currentIndex + 1) % zipFilesOnly.count
            targetZipPath = zipFilesOnly[nextIndex]
        } else {
            // 이미지 모드: 현재 파일 뒤에 있는 첫 번째 ZIP 찾기
            let currentPath = currentImagePath ?? ""
            if let idx = allFilesList.firstIndex(of: currentPath) {
                let suffix = allFilesList[(idx+1)...]
                if let nextZip = suffix.first(where: { $0.lowercased().hasSuffix(".zip") }) {
                    targetZipPath = nextZip
                } else {
                    // 뒤쪽에 없으면 첫 번째 ZIP (순환)
                    targetZipPath = zipFilesOnly.first!
                }
            } else {
                // 현재 파일 못 찾으면 첫 번째 ZIP
                targetZipPath = zipFilesOnly.first!
            }
        }

        // 해당 ZIP을 로드하고 첫 번째 이미지를 연다
        let didLoad = withSecurityScopedAccessForZip(at: targetZipPath) {
            loadZipFile(at: targetZipPath)
            if let firstImagePath = imagesInCurrentZip.first, FileManager.default.isReadableFile(atPath: firstImagePath) {
                if let firstImage = NSImage(contentsOfFile: firstImagePath) {
                    currentIndex = 0
                    currentImage = firstImage
                    currentImagePath = firstImagePath
                }
            } else {
                showPermissionAlertAndRetryOpenPanel(for: URL(fileURLWithPath: targetZipPath).deletingLastPathComponent())
            }
        }
        guard didLoad else {
            showZipPermissionAlert(for: targetZipPath)
            return
        }

        nextFileName = URL(fileURLWithPath: targetZipPath).lastPathComponent
        showNextFileInfo = true
    }
    
    private func nextImage() {
        if zipMode {
            // ZIP 모드에서는 ZIP 내부의 다음 이미지
            if currentIndex < imagesInCurrentZip.count - 1 {
                let nextImagePath = imagesInCurrentZip[currentIndex + 1]
                if FileManager.default.isReadableFile(atPath: nextImagePath) {
                    currentIndex += 1
                    if let nextImage = NSImage(contentsOfFile: nextImagePath) {
                        currentImage = nextImage
                        currentImagePath = nextImagePath
                    }
                } else {
                    showPermissionAlertAndRetryOpenPanel(for: URL(fileURLWithPath: nextImagePath).deletingLastPathComponent())
                }
            } else {
                // ZIP 내부의 마지막 이미지이면 다음 ZIP 파일로 이동
                handleRightBracketKey()
            }
        } else if !imagePaths.isEmpty {
            // 일반 모드에서는 다음 이미지
            if currentIndex < imagePaths.count - 1 {
                currentIndex += 1
                loadImage(at: imagePaths[currentIndex])
            }
        }
    }
    
    private func previousImage() {
        if zipMode {
            // ZIP 모드에서는 ZIP 내부의 이전 이미지
            if currentIndex > 0 {
                let prevImagePath = imagesInCurrentZip[currentIndex - 1]
                if FileManager.default.isReadableFile(atPath: prevImagePath) {
                    currentIndex -= 1
                    if let prevImage = NSImage(contentsOfFile: prevImagePath) {
                        currentImage = prevImage
                        currentImagePath = prevImagePath
                    }
                } else {
                    showPermissionAlertAndRetryOpenPanel(for: URL(fileURLWithPath: prevImagePath).deletingLastPathComponent())
                }
            } else {
                // ZIP 내부의 첫 이미지이면 이전 ZIP 파일로 이동
                handleLeftBracketKey()
            }
        } else if !imagePaths.isEmpty {
            // 일반 모드에서는 이전 이미지
            if currentIndex > 0 {
                currentIndex -= 1
                loadImage(at: imagePaths[currentIndex])
            }
        }
    }

    private func nextZipFile() {
        // 전체 목록에서 다음 파일로 이동
        if allFilesIndex < allFilesList.count - 1 {
            allFilesIndex += 1
            let nextFile = allFilesList[allFilesIndex]
            loadFile(at: nextFile)
        }
    }
    
    private func previousZipFile() {
        // 전체 목록에서 이전 파일로 이동
        if allFilesIndex > 0 {
            allFilesIndex -= 1
            let previousFile = allFilesList[allFilesIndex]
            loadFile(at: previousFile)
        }
    }
    
    private func presentAlertAsSheet(_ alert: NSAlert, completion: ((NSApplication.ModalResponse) -> Void)? = nil) {
        DispatchQueue.main.async {
            if let window = NSApp.keyWindow ?? NSApp.mainWindow {
                alert.beginSheetModal(for: window) { response in
                    completion?(response)
                }
            } else {
                let response = alert.runModal()
                completion?(response)
            }
        }
    }

    private func showPermissionAlert(for directory: URL) {
        let alert = NSAlert()
        alert.messageText = "폴더 접근 권한 필요"
        alert.informativeText = "선택한 폴더(\(directory.path))의 파일 목록을 읽기 위해 접근 권한이 필요합니다. 다시 시도해 주세요."
        alert.addButton(withTitle: "확인")
        alert.alertStyle = .warning
        presentAlertAsSheet(alert)
    }
    
    private func showPermissionAlertAndRetryOpenPanel(for directory: URL) {
        let alert = NSAlert()
        alert.messageText = "폴더 접근 권한 필요"
        alert.informativeText = "폴더(\(directory.path))에 접근 권한이 없습니다. 확인을 누르면 권한 선택 창을 자동으로 엽니다."
        alert.addButton(withTitle: "확인")
        alert.alertStyle = .warning
        presentAlertAsSheet(alert) { _ in
            openDirectoryPermissionPanel(for: directory)
        }
    }

    private func openDirectoryPermissionPanel(for directory: URL) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.directoryURL = directory
        panel.prompt = "권한 허용"
        panel.message = "접근 권한을 허용할 폴더를 선택해 주세요"

        if panel.runModal() == .OK, let selectedDirectoryURL = panel.url {
            let didAccess = withSecurityScopedAccessForDirectory(at: selectedDirectoryURL) {
                savedDirectory = selectedDirectoryURL.path
                createAllFilesListFromDirectory(selectedDirectoryURL.path)
                updateZipFilesList(in: selectedDirectoryURL.path)
            }

            if !didAccess {
                showPermissionAlert(for: selectedDirectoryURL)
            }
        }
    }

    private func withSecurityScopedAccessForZip(at zipPath: String, action: () -> Void) -> Bool {
        let directoryURL = URL(fileURLWithPath: zipPath).deletingLastPathComponent()

        if let bookmarkedURL = PermissionManager.shared.resolveBookmark(for: directoryURL.path) {
            defer { bookmarkedURL.stopAccessingSecurityScopedResource() }
            action()
            return true
        }

        if directoryURL.startAccessingSecurityScopedResource() {
            defer { directoryURL.stopAccessingSecurityScopedResource() }
            PermissionManager.shared.saveBookmark(for: directoryURL)
            action()
            return true
        }

        return false
    }

    private func showZipPermissionAlert(for zipPath: String) {
        let zipName = URL(fileURLWithPath: zipPath).lastPathComponent
        let alert = NSAlert()
        alert.messageText = "ZIP 접근 권한 필요"
        alert.informativeText = "\(zipName) 파일을 열 권한이 없습니다. 폴더를 다시 선택해 권한을 부여해 주세요."
        alert.addButton(withTitle: "확인")
        alert.alertStyle = .warning
        presentAlertAsSheet(alert)
    }

    private func openZipPickerInCurrentDirectory() {
        guard let directoryPath = currentDirectoryPathForZipSelection() else {
            showNoCurrentDirectoryAlertForZipSelection()
            return
        }

        let directoryURL = URL(fileURLWithPath: directoryPath, isDirectory: true)
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.zip]
        panel.directoryURL = directoryURL
        panel.prompt = "ZIP 열기"

        let didAccess = withSecurityScopedAccessForDirectory(at: directoryURL) {
            if panel.runModal() == .OK, let selectedURL = panel.url {
                let selectedDirectory = selectedURL.deletingLastPathComponent().path
                guard selectedDirectory == directoryPath else {
                    showZipSelectionOutOfCurrentDirectoryAlert(directoryPath: directoryPath)
                    return
                }
                processSelectedURL(selectedURL)
            }
        }

        if !didAccess {
            showPermissionAlertAndRetryOpenPanel(for: directoryURL)
        }
    }

    private func currentDirectoryPathForZipSelection() -> String? {
        if let savedDirectory {
            return savedDirectory
        }
        if let currentImagePath {
            return URL(fileURLWithPath: currentImagePath).deletingLastPathComponent().path
        }
        if let currentZipPath = zipManager.currentZipPath {
            return URL(fileURLWithPath: currentZipPath).deletingLastPathComponent().path
        }
        return nil
    }

    private func withSecurityScopedAccessForDirectory(at directoryURL: URL, action: () -> Void) -> Bool {
        if let bookmarkedURL = PermissionManager.shared.resolveBookmark(for: directoryURL.path) {
            defer { bookmarkedURL.stopAccessingSecurityScopedResource() }
            action()
            return true
        }

        if directoryURL.startAccessingSecurityScopedResource() {
            defer { directoryURL.stopAccessingSecurityScopedResource() }
            PermissionManager.shared.saveBookmark(for: directoryURL)
            action()
            return true
        }

        return false
    }

    private func showNoCurrentDirectoryAlertForZipSelection() {
        let alert = NSAlert()
        alert.messageText = "현재 폴더 정보 없음"
        alert.informativeText = "먼저 파일 또는 폴더를 열어 현재 작업 폴더를 설정해 주세요."
        alert.addButton(withTitle: "확인")
        alert.alertStyle = .warning
        presentAlertAsSheet(alert)
    }

    private func showZipSelectionOutOfCurrentDirectoryAlert(directoryPath: String) {
        let alert = NSAlert()
        alert.messageText = "다른 폴더의 ZIP은 열 수 없음"
        alert.informativeText = "o 키로는 현재 폴더(\(directoryPath)) 안의 ZIP 파일만 선택할 수 있습니다."
        alert.addButton(withTitle: "확인")
        alert.alertStyle = .warning
        presentAlertAsSheet(alert)
    }
}

#Preview {
    ContentView()
}
