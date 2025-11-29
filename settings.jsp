<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"
         import="java.util.*, java.sql.*" %>
<%@ include file="dbconn.jsp" %>
<%
    request.setCharacterEncoding("UTF-8");

    String currentUser = (String) session.getAttribute("currentUser");
    Boolean currentPaid = (Boolean) session.getAttribute("currentUserPaid");
    if (currentPaid == null) currentPaid = false;

    if (currentUser == null || currentUser.trim().isEmpty()) {
        if (con != null) { try { con.close(); } catch (Exception ignore) {} }
        response.sendRedirect("login.jsp");
        return;
    }

    // 기본 이니셜 계산
    String initials = currentUser.substring(0,1).toUpperCase();

    String infoMessage = null;
    String errorMessage = null;

    // 액션 처리 (텍스트 정보 수정 및 비공개 설정)
    String action = request.getParameter("action");
    if (action != null) action = action.trim();

    try {
        if ("update_profile".equals(action)) {
            String addr  = request.getParameter("address");
            String phone = request.getParameter("phone_number");
            String sm    = request.getParameter("status_message");

            if (addr  != null) addr  = addr.trim();
            if (phone != null) phone = phone.trim();
            if (sm    != null) sm    = sm.trim();

            String usql = "UPDATE users SET address = ?, phone_number = ?, status_message = ? WHERE user_id = ?";
            try (PreparedStatement ps = con.prepareStatement(usql)) {
                if (addr == null || addr.isEmpty())   ps.setNull(1, Types.VARCHAR);
                else                                  ps.setString(1, addr);
                if (phone == null || phone.isEmpty()) ps.setNull(2, Types.VARCHAR);
                else                                  ps.setString(2, phone);
                if (sm == null || sm.isEmpty())       ps.setNull(3, Types.VARCHAR);
                else                                  ps.setString(3, sm);
                ps.setString(4, currentUser);
                ps.executeUpdate();
            }
            infoMessage = "개인정보가 수정되었습니다";

        } else if ("update_privacy".equals(action)) {
            String priv = request.getParameter("is_private");
            String flag = "F";
            if ("T".equals(priv) || "on".equalsIgnoreCase(priv)) {
                flag = "T";
            }
            String psql = "UPDATE users SET is_private = ? WHERE user_id = ?";
            try (PreparedStatement ps = con.prepareStatement(psql)) {
                ps.setString(1, flag);
                ps.setString(2, currentUser);
                ps.executeUpdate();
            }
            if ("T".equals(flag)) infoMessage = "비밀계정이 활성화되었습니다. 이제 팔로워만 게시글을 볼 수 있습니다";
            else infoMessage = "비밀계정이 해제되었습니다. 다시 공개 계정이 되었습니다";
        }
    } catch (SQLIntegrityConstraintViolationException e) {
        errorMessage = "전화번호가 중복됩니다. 다른 번호를 입력해 주세요";
    } catch (Exception e) {
        e.printStackTrace();
        errorMessage = "설정 변경 중 오류가 발생했습니다";
    }

    // 최신 유저 정보 읽기 (프로필 이미지 포함)
    String address = null;
    String phone   = null;
    String status  = null;
    String paidStr = null;
    String isPrivate = "F";
    String profileImg = null;

    try {
        String q = "SELECT address, phone_number, status_message, paid, is_private, profile_img FROM users WHERE user_id = ?";
        try (PreparedStatement ps = con.prepareStatement(q)) {
            ps.setString(1, currentUser);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    address   = rs.getString("address");
                    phone     = rs.getString("phone_number");
                    status    = rs.getString("status_message");
                    paidStr   = rs.getString("paid");
                    isPrivate = rs.getString("is_private");
                    profileImg = rs.getString("profile_img");
                    if (isPrivate == null) isPrivate = "F";
                }
            }
        }
    } catch (Exception e) {
        e.printStackTrace();
        if (errorMessage == null) errorMessage = "사용자 정보를 불러오는 중 오류가 발생했습니다";
    }

    boolean isPaid = "T".equals(paidStr);
    session.setAttribute("currentUserPaid", isPaid);
%>
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>설정 / TWITTER_DB4</title>
    <link rel="stylesheet" href="style.css">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    <link href="https://fonts.googleapis.com/css2?family=Poppins:wght@800&display=swap" rel="stylesheet">
    <style>
        /* 프로필 이미지 컨테이너 및 연필 아이콘 스타일 */
        .profile-image-wrapper {
            position: relative;
            display: inline-block;
            width: 48px;  /* avatar-lg 사이즈 */
            height: 48px;
        }
        .profile-image-wrapper img {
            width: 100%;
            height: 100%;
            border-radius: 50%;
            object-fit: cover;
            border: 1px solid #e1e8ed;
        }
        .edit-icon-overlay {
            position: absolute;
            bottom: -2px;
            right: -2px;
            width: 20px;
            height: 20px;
            background-color: #fff;
            border: 1px solid #cfd9de;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            cursor: pointer;
            box-shadow: 0 1px 3px rgba(0,0,0,0.1);
            color: #536471;
            font-size: 10px;
        }
        .edit-icon-overlay:hover {
            background-color: #f7f9f9;
            color: #1d9bf0;
        }
    </style>
</head>
<body>
<div class="app-shell">

    <header class="app-header">
        <div class="app-header-left">
            <a href="main.jsp" class="app-logo">TWITTER_DB4</a>
            <div class="app-logo-sub">설정</div>
        </div>
        <div class="app-header-right">
            <% if (currentUser == null) { %>
                <a href="login.jsp" class="icon-btn" title="로그인"><i class="fa-solid fa-user"></i></a>
            <% } else { %>
                <a href="followList.jsp" class="icon-btn" title="사용자 검색"><i class="fa-solid fa-magnifying-glass"></i></a>
                <a href="profile.jsp" class="icon-btn" title="내 프로필"><%= initials %></a>
                <a href="settings.jsp" class="icon-btn" title="설정"><i class="fa-solid fa-gear"></i></a>
                <a href="messages.jsp" class="icon-btn" title="메시지"><i class="fa-regular fa-comments"></i></a>
            <% } %>
        </div>
    </header>

    <div style="width: 100%; max-width: 600px; margin: 20px auto; padding: 0 16px;">
        
        <div class="card">
            <div style="display:flex; gap:16px; align-items:center; margin-bottom:12px;">
                
                <div class="profile-image-wrapper">
                    <% if(profileImg != null && !profileImg.isEmpty()) { %>
                        <img src="uploads/<%= profileImg %>" alt="프로필">
                    <% } else { %>
                        <div class="avatar-lg"><%= initials %></div>
                    <% } %>
                    
                    <label for="p-upload" class="edit-icon-overlay" title="프로필 사진 변경">
                        <i class="fa-solid fa-pencil"></i>
                    </label>
                    <form action="updateProfileImage.jsp" method="post" enctype="multipart/form-data" style="display:none;">
                        <input type="file" id="p-upload" name="profileImage" accept="image/*" onchange="this.form.submit()">
                    </form>
                </div>

                <div>
                    <div class="post-username-row">
                        <span class="username-link" style="font-size:18px;"><%= currentUser %></span>
                        <% if (isPaid) { %> <span class="badge-check">✓</span> <% } %>
                    </div>
                    <div class="post-meta">
                        <%= (status == null || status.trim().isEmpty()) ? "상태메시지 없음" : status %>
                    </div>
                    <div class="post-meta" style="margin-top:4px;">
                        계정 유형: <strong><%= "T".equals(isPrivate) ? "비밀 계정" : "공개 계정" %></strong>
                    </div>
                </div>
            </div>

            <% if (infoMessage != null) { %> <div class="msg msg-ok"><%= infoMessage %></div> <% } %>
            <% if (errorMessage != null) { %> <div class="msg msg-err"><%= errorMessage %></div> <% } %>
        </div>

        <div class="card">
            <div class="section-title">개인정보 수정</div>
            <form method="post" action="settings.jsp" style="margin-bottom: 20px;">
                <input type="hidden" name="action" value="update_profile">

                <div class="form-row" style="margin-bottom:15px;">
                    <div class="form-label">주소</div>
                    <div class="input-wrapper-icon">
                        <i class="fa-solid fa-location-dot icon-inside-input"></i>
                        <input type="text" name="address" class="input-text has-icon" 
                               value="<%= (address==null)?"":address %>" placeholder="주소를 입력하세요">
                    </div>
                </div>
                
                <div class="form-row" style="margin-bottom:15px;">
                    <div class="form-label">전화번호</div>
                    <div class="input-wrapper-icon">
                        <i class="fa-solid fa-phone icon-inside-input"></i>
                        <input type="text" name="phone_number" class="input-text has-icon" 
                               value="<%= (phone==null)?"":phone %>" placeholder="전화번호를 입력하세요">
                    </div>
                </div>

                <div class="form-row" style="margin-bottom:15px;">
                    <div class="form-label">상태메시지</div>
                    <textarea name="status_message" class="input-text" rows="3" 
                              placeholder="여기에 입력하세요..." style="resize:none;"><%= (status==null)?"":status %></textarea>
                </div>

                <div style="display:flex; justify-content:flex-end;">
                    <button type="submit" class="btn-primary">저장</button>
                </div>
            </form>
        </div>

        <div class="card">
            <div class="section-title">비밀 계정 설정</div>
            <div class="helper-text" style="margin-bottom:12px;">
                비밀 계정을 활성화하면 팔로워로 승인된 사용자만 회원님의 게시글을 볼 수 있습니다.<br>
                팔로우 요청은 회원님이 승인해야 팔로워가 됩니다.
            </div>
            <form method="post" action="settings.jsp">
                <input type="hidden" name="action" value="update_privacy">
                <div class="form-row" style="margin-bottom:12px;">
                    <label style="margin-right:15px; cursor:pointer;">
                        <input type="radio" name="is_private" value="F" <%= !"T".equals(isPrivate) ? "checked" : "" %>>
                        공개 계정
                    </label>
                    <label style="cursor:pointer;">
                        <input type="radio" name="is_private" value="T" <%= "T".equals(isPrivate) ? "checked" : "" %>>
                        비밀 계정
                    </label>
                </div>
                <div style="display:flex; justify-content:flex-end;">
                    <button type="submit" class="btn-secondary">변경 적용</button>
                </div>
            </form>
        </div>

        <div class="card">
            <div class="section-title">구독 설정</div>
            <p class="helper-text">
                유료 구독을 신청하거나 기간을 연장하려면 아래 버튼을 클릭하세요.
            </p>
            <a href="subscribe.jsp" class="btn-primary btn-sm">구독 결제 페이지로 이동</a>
        </div>

        <div class="card">
            <div class="section-title">계정 관리</div>
            <p class="helper-text">
                현재 계정에서 로그아웃하거나 탈퇴할 수 있습니다.
            </p>
            
            <div style="display:flex; gap:10px;">
                <form method="post" action="logout.jsp" style="margin:0;">
                    <button type="submit" class="btn-secondary btn-sm">로그아웃</button>
                </form>

                <form method="post" action="deleteAccount.jsp" style="margin:0;" 
                      onsubmit="return confirm('정말로 탈퇴하시겠습니까?\n모든 데이터가 영구적으로 삭제됩니다.');">
                    <button type="submit" class="btn-danger btn-sm" style="background-color: #f4212e; color: white; border: none;">회원 탈퇴</button>
                </form>
            </div>
        </div>

    </div> </div>
</body>
</html>
<% if (con != null) { try { con.close(); } catch (Exception ignore) {} } %>