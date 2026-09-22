import SwiftUI
import SwiftData
import UserNotifications

struct DownloadsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: DownloadsViewModel
    @State private var refreshTimer: Timer?
    @State private var showClearConfirmation = false
    
    init() {
        _viewModel = State(initialValue: DownloadsViewModel())
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                List {
                    Section("Available Files") {
                        ForEach(viewModel.availableFiles, id: \.id) { file in
                            AvailableFileRowView(file: file, viewModel: viewModel)
                        }
                    }
                    
                    if !viewModel.downloadedFiles.isEmpty {
                        Section("Downloaded Files") {
                            ForEach(viewModel.downloadedFiles) { download in
                                DownloadedFileRowView(download: download, viewModel: viewModel)
                            }
                            .onDelete { indexSet in
                                for index in indexSet {
                                    viewModel.deleteDownload(viewModel.downloadedFiles[index])
                                }
                            }
                        }
                    }
                    
                    if !viewModel.activeDownloads.isEmpty {
                        Section("Active Downloads") {
                            ForEach(viewModel.activeDownloads) { download in
                                ActiveDownloadRowView(download: download, viewModel: viewModel)
                            }
                        }
                    }
                }
                .navigationTitle("Downloads")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        if !viewModel.downloadedFiles.isEmpty {
                            Button(action: { showClearConfirmation = true }) {
                                Image(systemName: "trash.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
                .confirmationDialog(
                    "Clear Downloaded Files?",
                    isPresented: $showClearConfirmation,
                    actions: {
                        Button("Clear All", role: .destructive) {
                            viewModel.clearAllDownloadedFiles()
                        }
                        Button("Cancel", role: .cancel) {}
                    },
                    message: {
                        Text("This will delete all \(viewModel.downloadedFiles.count) downloaded file(s) and cannot be undone.")
                    }
                )
            }
        }
        .onAppear {
            viewModel.setup(modelContext: modelContext)
            requestNotificationPermission()
            startRefreshTimer()
        }
        .onDisappear {
            refreshTimer?.invalidate()
        }
    }
    
    private func startRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            viewModel.refreshDownloads()
        }
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            if granted {
                print("Notification permission granted")
            }
        }
    }
}

struct AvailableFileRowView: View {
    let file: DownloadableFile
    let viewModel: DownloadsViewModel
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(file.name)
                    .font(.headline)
                Text(viewModel.getFormattedFileSize(file.fileSize))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Button(action: { viewModel.initiateDownload(file) }) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 8)
    }
}

struct ActiveDownloadRowView: View {
    let download: FileDownload
    let viewModel: DownloadsViewModel
    @State private var refreshTimer: Timer?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(download.fileName)
                        .font(.headline)
                        .lineLimit(1)
                }
                
                Spacer()
                
                StatusBadgeView(status: download.status)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: viewModel.getDownloadProgress(download))
                    .tint(.blue)
                
                HStack {
                    Text("\(viewModel.getFormattedFileSize(download.downloadedSize)) / \(viewModel.getFormattedFileSize(download.fileSize))")
                        .font(.caption)
                    Spacer()
                    Text(viewModel.getDownloadProgressPercentage(download))
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            startRefreshTimer()
        }
        .onDisappear {
            refreshTimer?.invalidate()
        }
    }
    
    private func startRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            // Trigger refresh
        }
    }
}

struct DownloadedFileRowView: View {
    let download: FileDownload
    let viewModel: DownloadsViewModel
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(download.fileName)
                    .font(.headline)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Downloaded")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            
            Spacer()
            
            if let path = download.localPath {
                Button(action: { openFile(at: path) }) {
                    Image(systemName: "arrow.up.right.square")
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func openFile(at path: String) {
        let url = URL(fileURLWithPath: path)
        UIApplication.shared.open(url)
    }
}


#Preview {
    DownloadsView()
        .modelContainer(for: FileDownload.self, inMemory: true)
}
