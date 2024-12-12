// Add at bottom of file

#Preview {
    AudioPlayerView(audioModel: PreviewMocks.audioModel)
        .frame(height: 200)
        .padding()
        .previewLayout(.sizeThatFits)
}

#Preview("Playing State") {
    let model = PreviewMocks.audioModel
    model.isPlaying = true
    return AudioPlayerView(audioModel: model)
        .frame(height: 200)
        .padding()
        .previewLayout(.sizeThatFits)
}

#Preview("With Progress") {
    let model = PreviewMocks.audioModel
    model.currentTime = 30
    model.duration = 120
    return AudioPlayerView(audioModel: model)
        .frame(height: 200)
        .padding()
        .previewLayout(.sizeThatFits)
}