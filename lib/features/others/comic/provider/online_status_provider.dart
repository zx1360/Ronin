import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/others/comic/models/chapter_info.dart';
import 'package:torrid/features/others/comic/models/comic_info.dart';
import 'package:torrid/providers/api_client/api_client_provider.dart';

part 'online_status_provider.g.dart';

// 获取所有漫画信息
@riverpod
Future<List<ComicInfo>> comicsOnline(ComicsOnlineRef ref)async{
  final response = await ref.read(fetcherProvider(path: "/api/comic/comic-info").future);
  if(response==null){
    return [];
  }
  final comics = <ComicInfo>[];
  for (final row in response.data){
    comics.add(ComicInfo.fromJson(row));
  }
  return comics;
}

// 根据comicId获取对应的章节信息
@riverpod
Future<List<ChapterInfo>> onlineChaptersWithComicId(OnlineChaptersWithComicIdRef ref, {required String comicId})async{
  final response = await ref.read(fetcherProvider(path: "/api/comic/comic-info/$comicId").future);
  if(response==null){
    return [];
  }
  final comics = <ChapterInfo>[];
  for (final row in response.data){
    comics.add(ChapterInfo.fromJson(row));
  }
  return comics;
}

// 根据chapterId获取对应的章节信息
@riverpod
Future<List<Map<String, dynamic>>> onlineImagesWithChapterId(OnlineImagesWithChapterIdRef ref, {required String chapterId})async{
  final response = await ref.read(fetcherProvider(path: "/api/comic/chapter-info/$chapterId").future);
  if(response==null){
    return [];
  }
  final images = <Map<String, dynamic>>[];
  for (final row in response.data){
    images.add(row);
  }
  return images;
}
