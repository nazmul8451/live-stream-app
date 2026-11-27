import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../model/trade_vote_model.dart';
import '../../../../global/widgets/custom_shimmer.dart';
import 'package:live_stream_app/global/widgets/button_loader.dart';

const _cardColor = Color(0xFF13131D);
const _accent = Color(0xFF8B9BFF);

/// One finished trade, two sides, and a single question. Both sides look the
/// same until someone votes, so the card never nudges the answer.
class TradeVoteCard extends StatelessWidget {
  final TradeVoteModel trade;
  final Function(TradeVoteModel trade, String option) onVote;
  final bool showHeaderArrows;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final String? counterText;
  final bool isCompact;

  const TradeVoteCard({
    super.key,
    required this.trade,
    required this.onVote,
    this.showHeaderArrows = false,
    this.onPrev,
    this.onNext,
    this.counterText,
    this.isCompact = false,
  });

  String get _nameA => trade.itemA.traderName.isNotEmpty ? trade.itemA.traderName : 'Trader A';
  String get _nameB => trade.itemB.traderName.isNotEmpty ? trade.itemB.traderName : 'Trader B';

  @override
  Widget build(BuildContext context) {
    final meta = [
      if (trade.category.isNotEmpty) _sentence(trade.category),
      if (trade.timeAgo.isNotEmpty) trade.timeAgo,
    ].join(' · ');

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      padding: EdgeInsets.all(isCompact ? 14.r : 16.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Who won this trade?",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isCompact ? 16.sp : 17.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (meta.isNotEmpty) ...[
                      SizedBox(height: 2.h),
                      Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white54, fontSize: 12.5.sp),
                      ),
                    ],
                  ],
                ),
              ),
              if (showHeaderArrows)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onPrev != null) _arrow(Icons.chevron_left_rounded, onPrev!),
                    if (counterText != null)
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4.w),
                        child: Text(
                          counterText!,
                          style: TextStyle(color: Colors.white54, fontSize: 12.sp, fontWeight: FontWeight.w500),
                        ),
                      ),
                    if (onNext != null) _arrow(Icons.chevron_right_rounded, onNext!),
                  ],
                )
              else
                Obx(() => Text(
                      _votes(trade.totalVotes.value),
                      style: TextStyle(color: Colors.white54, fontSize: 12.sp),
                    )),
            ],
          ),

          SizedBox(height: isCompact ? 12.h : 16.h),

          Obx(() {
            final hasVoted = trade.hasVoted.value;
            final votedOption = trade.votedOption.value;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildItemCard(
                    sideTag: "Trader A",
                    traderName: trade.itemA.traderName,
                    name: trade.itemA.name,
                    value: trade.itemA.value,
                    imageUrl: trade.itemA.formattedImageUrl,
                    isVoted: hasVoted && votedOption == "A",
                    accentColor: _accent,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: isCompact ? 36.h : 46.h),
                  child: Icon(Icons.swap_horiz_rounded, color: Colors.white30, size: 18.sp),
                ),
                Expanded(
                  child: _buildItemCard(
                    sideTag: "Trader B",
                    traderName: trade.itemB.traderName,
                    name: trade.itemB.name,
                    value: trade.itemB.value,
                    imageUrl: trade.itemB.formattedImageUrl,
                    isVoted: hasVoted && votedOption == "B",
                    accentColor: _accent,
                  ),
                ),
              ],
            );
          }),

          SizedBox(height: isCompact ? 12.h : 16.h),

          Obx(() {
            final hasVoted = trade.hasVoted.value;
            final isVoting = trade.isVoting.value;

            if (!hasVoted) {
              if (isVoting) {
                return SizedBox(height: 42.h, child: Center(child: ButtonLoader(size: 18)));
              }
              return Row(
                children: [
                  Expanded(child: _voteButton(_nameA, () => onVote(trade, "A"))),
                  SizedBox(width: 10.w),
                  Expanded(child: _voteButton(_nameB, () => onVote(trade, "B"))),
                ],
              );
            }

            final pctA = trade.percentageA.value;
            final pctB = trade.percentageB.value;
            final chosen = trade.votedOption.value == "A" ? _nameA : _nameB;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "$_nameA  $pctA%",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.w600),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Flexible(
                      child: Text(
                        "$pctB%  $_nameB",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: TextStyle(color: Colors.white70, fontSize: 13.sp, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4.r),
                  child: SizedBox(
                    height: 6.h,
                    child: Row(
                      children: [
                        Expanded(flex: pctA > 0 ? pctA : 1, child: Container(color: _accent)),
                        SizedBox(width: 2.w),
                        Expanded(flex: pctB > 0 ? pctB : 1, child: Container(color: Colors.white24)),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  "You voted for $chosen · ${_votes(trade.totalVotes.value)}",
                  style: TextStyle(color: Colors.white54, fontSize: 12.sp),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  static String _votes(int n) => n == 1 ? "1 vote" : "$n votes";

  static String _sentence(String s) {
    final t = s.trim().toLowerCase();
    return t.isEmpty ? t : t[0].toUpperCase() + t.substring(1);
  }

  Widget _arrow(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.all(4.r),
        child: Icon(icon, color: Colors.white60, size: 22.sp),
      ),
    );
  }

  Widget _voteButton(String name, VoidCallback onTap) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
        padding: EdgeInsets.symmetric(vertical: isCompact ? 10.h : 12.h, horizontal: 8.w),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
      ),
      child: Text(
        "Vote $name",
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildItemCard({
    required String sideTag,
    required String traderName,
    required String name,
    required String value,
    required String imageUrl,
    required bool isVoted,
    required Color accentColor,
  }) {
    final imageHeight = isCompact ? 96.h : 116.h;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: imageHeight,
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(
              color: isVoted ? accentColor : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: imageUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => CustomShimmer.rectangular(
                    width: double.infinity,
                    height: imageHeight,
                  ),
                  errorWidget: (context, url, error) => _buildImageFallback(),
                )
              : _buildImageFallback(),
        ),
        SizedBox(height: 8.h),
        Text(
          name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontSize: 13.sp,
            fontWeight: FontWeight.w500,
            height: 1.25,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          [traderName.isNotEmpty ? traderName : sideTag, if (value.isNotEmpty) value].join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Colors.white54, fontSize: 12.sp),
        ),
      ],
    );
  }

  Widget _buildImageFallback() {
    return Container(
      alignment: Alignment.center,
      child: Icon(Icons.style_outlined, color: Colors.white24, size: 28.sp),
    );
  }
}
